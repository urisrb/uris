require "test_helper"
require_relative "../../support/fake_imap_server"

class ImapResourceTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    ENV["URIS_ALLOW_PRIVATE_FETCH"] = "1"

    @server = FakeImapServer.current
    @server.reset!
    @server.deliver subject: "March invoice", body: "The invoice total is 42 pounds."
    @server.deliver subject: "Beach photos", body: "Pictures from the trip."

    @tenant = Tenant.create!(subdomain: "imap-#{SecureRandom.hex(4)}", name: "Mail")

    Tenant.switch(@tenant) do
      @resource = Resource::Imap.create!(
        key: "box-#{SecureRandom.hex(4)}@localhost",
        name: "Mail",
        details: { "host" => @server.host, "port" => @server.port, "ssl" => false },
        credentials: { "username" => "someone", "password" => "irrelevant" }
      )
    end
  end

  teardown { ENV.delete("URIS_ALLOW_PRIVATE_FETCH") }

  test "a server inside the network is refused before it is dialled" do
    ENV.delete("URIS_ALLOW_PRIVATE_FETCH")

    Tenant.switch(@tenant) do
      [ @server.host, "169.254.169.254", "::ffff:10.0.0.5" ].each do |host|
        @resource.update!(details: @resource.details.merge("host" => host))

        assert_raises(PublicFetch::Blocked, host) { @resource.check! }
      end
    end
  end

  test "a public name is dialled at the address it was vetted at, and still verified as that name" do
    dialled = []
    Socket.singleton_class.alias_method(:unpinned_tcp, :tcp)
    Socket.define_singleton_method(:tcp) do |host, port, **options|
      dialled << host
      unpinned_tcp(FakeImapServer.current.host, port, **options)
    end

    Tenant.switch(@tenant) do
      @resource.update!(details: @resource.details.merge("host" => "mail.example.test"))

      assert @resource.check!
      assert_equal "mail.example.test", @resource.send(:connect) { |imap| imap.host }
    end

    assert_equal [ Offline::PUBLIC ], dialled.uniq
  ensure
    Socket.singleton_class.alias_method(:tcp, :unpinned_tcp)
  end

  test "syncing a mailbox catalogues every message as an email item" do
    sync

    Tenant.switch(@tenant) do
      assert_equal 2, Feed.files.count
      assert_equal [ "message/rfc822", "message/rfc822" ], Reference.pluck(:mime)
      assert_equal [ "Beach photos", "March invoice" ], Feed.pluck(:title).sort
    end
  end

  test "the locator names the generation a UID belongs to" do
    sync

    Tenant.switch(@tenant) do
      reference = titled("March invoice").references.first

      assert_equal "INBOX", reference.locator["mailbox"]
      assert_equal @server.uidvalidity, reference.locator["uidvalidity"]
      assert_equal 1, reference.locator["uid"]
      assert_equal "INBOX/#{@server.uidvalidity}/1", reference.locator_key
    end
  end

  test "a cursor from a previous generation restarts rather than skipping" do
    stale = []
    @resource.each_page(cursor: "#{@server.uidvalidity - 1}:9999") { |page, _| stale.concat(page) }

    assert_equal 2, stale.size
  end

  test "a cursor from this generation is honoured" do
    seen = []
    @resource.each_page(cursor: "#{@server.uidvalidity}:9999") { |page, _| seen.concat(page) }

    assert_empty seen
  end

  test "a renumbered mailbox catalogues afresh rather than reusing a UID" do
    sync
    @server.renumber!
    sync

    Tenant.switch(@tenant) do
      assert_equal 4, Feed.files.count
      assert_equal [ "INBOX/1/1", "INBOX/1/2", "INBOX/2/1", "INBOX/2/2" ],
                   Reference.pluck(:locator_key).sort
    end
  end

  test "a reference from a previous generation refuses to resolve" do
    sync
    @server.renumber!

    Tenant.switch(@tenant) do
      error = assert_raises(Resource::Failed) { titled("March invoice").references.first.download }

      assert_match(/renumbered/, error.message)
    end
  end

  test "downloading a reference returns the message source" do
    sync

    Tenant.switch(@tenant) do
      source = titled("March invoice").references.first.download.read

      assert_includes source, "Subject: March invoice"
      assert_includes source, "The invoice total is 42 pounds."
    end
  end

  test "the email analyzer reads a message off the server" do
    sync

    Tenant.switch(@tenant) do
      item = titled("March invoice")
      Tenant.switch(@tenant) { AnalyzeFeedJob.perform_now(@tenant.id, item.id) }

      analysis = item.reload.analysis.steps

      assert_equal "March invoice", analysis.dig("headers", "result", "subject")
      assert_includes analysis.dig("text", "result"), "42 pounds"
    end
  end

  test "syncing does not mark anything read" do
    sync

    Tenant.switch(@tenant) { titled("March invoice").references.first.download.read }

    assert_not_includes @server.flags.flatten, "\\Seen"
  end

  test "syncing twice converges rather than accumulating" do
    2.times { sync }

    Tenant.switch(@tenant) { assert_equal 2, Feed.files.count }
  end

  test "a mailbox is not storage and cannot be an export destination" do
    assert_not @resource.storage?
    assert_raises(ArgumentError) { @resource.storage! }
  end

  test "an unreachable server is recorded rather than raised" do
    Tenant.switch(@tenant) do
      @resource.update!(details: @resource.details.merge("port" => 1))

      assert_not @resource.check
      assert_match(/#{Regexp.escape(@resource.key)}/, @resource.check_error)
    end
  end

  private

    def sync
      Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }
    end

    def titled(title)
      Feed.find_by!(title: title)
    end
end
