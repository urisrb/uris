require "test_helper"
require_relative "../support/fake_dav_server"

class WebdavResourceTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    ENV["URIS_ALLOW_PRIVATE_FETCH"] = "1"

    @server = FakeDavServer.current
    @server.reset!
    @server.put "invoices/march.pdf", "contents of march"
    @server.put "photos/beach.jpg", "contents of beach"
    @server.put "notes.txt", "remember the milk"

    @tenant = Tenant.create!(subdomain: "dav-#{SecureRandom.hex(4)}", name: "Dav")

    Tenant.switch(@tenant) do
      @resource = Resource::Webdav.create!(
        key: "dav-#{SecureRandom.hex(4)}",
        name: "Files",
        details: { "url" => @server.url },
        credentials: { "username" => "someone", "password" => "irrelevant" }
      )
    end
  end

  teardown do
    ENV.delete("URIS_ALLOW_PRIVATE_FETCH")
  end

  test "syncing walks collections and catalogues every file" do
    sync

    Tenant.switch(@tenant) do
      assert_equal 3, Item.count
      assert_equal "pdf", thing_at("invoices/march.pdf").kind
      assert_equal "march.pdf", thing_at("invoices/march.pdf").title
      assert_equal "image", thing_at("photos/beach.jpg").kind
      assert_equal "text", thing_at("notes.txt").kind
    end
  end

  test "the locator carries the etag, so a change has a signal to hang on" do
    sync

    Tenant.switch(@tenant) do
      assert thing_at("notes.txt").references.first.locator["etag"].present?
    end
  end

  test "the bytes come back through the reference" do
    sync

    Tenant.switch(@tenant) do
      assert_equal "remember the milk", thing_at("notes.txt").references.first.download.read
    end
  end

  test "syncing twice converges rather than accumulating" do
    2.times { sync }

    Tenant.switch(@tenant) { assert_equal 3, Item.count }
  end

  test "a cursor resumes where the walk stopped" do
    seen = []
    @resource.each_page(cursor: "invoices/march.pdf") { |page, _| seen.concat(page.map(&:path)) }

    assert_equal [ "notes.txt", "photos/beach.jpg" ], seen
  end

  test "it is storage, and uploading creates the collections it needs" do
    @resource.upload("backup/deep/notes.txt", "written by items")

    assert_equal "written by items", @server.read("backup/deep/notes.txt")
  end

  test "export writes into it and records the second reference" do
    Tenant.switch(@tenant) do
      destination = Resource::Webdav.create!(
        key: "backup-#{SecureRandom.hex(4)}",
        details: { "url" => @server.url, "prefix" => "backup" },
        credentials: { "username" => "someone", "password" => "irrelevant" }
      )
      sync
      ExportItemsJob.perform_now(@tenant.id, destination.id, { "kind" => "text" })

      assert_equal "remember the milk", @server.read("#{@resource.key}/notes.txt")
      assert_equal 2, thing_at("notes.txt").references.count
    end
  end

  test "a resource whose credentials went missing fails rather than reading anonymously" do
    Tenant.switch(@tenant) do
      @resource.update!(credentials: {})

      assert_raises(Resource::Failed) { @resource.check! }
    end
  end

  test "a private address is refused unless fetching them is allowed" do
    ENV.delete("URIS_ALLOW_PRIVATE_FETCH")

    assert_raises(PublicFetch::Blocked) { @resource.check! }
  end

  private

    def sync
      SyncResourceJob.perform_now(@tenant.id, @resource.id)
    end

    def thing_at(locator_key)
      Item.joins(:references).find_by!(item_references: { locator_key: locator_key })
    end
end
