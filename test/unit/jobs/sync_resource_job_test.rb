require "test_helper"

class SyncResourceJobTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "sync-#{SecureRandom.hex(4)}", name: "Sync")
    @other = Tenant.create!(subdomain: "other-#{SecureRandom.hex(4)}", name: "Other")
    @bucket = "test-#{SecureRandom.hex(6)}"

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(
        key: @bucket,
        name: "Test bucket",
        details: {
          "endpoint" => ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
          "region" => ENV.fetch("S3_REGION", "us-east-1")
        },
        credentials: {
          "access_key_id" => ENV.fetch("S3_ACCESS_KEY_ID", "items"),
          "secret_access_key" => ENV.fetch("S3_SECRET_ACCESS_KEY", "urisuris")
        }
      )
    end

    @resource.client.create_bucket(bucket: @bucket)
    put "invoices/march.pdf"
    put "photos/beach.jpg"
    put "notes.txt"
  end

  teardown do
    objects = @resource.client.list_objects_v2(bucket: @bucket).contents
    objects.each { |o| @resource.client.delete_object(bucket: @bucket, key: o.key) }
    @resource.client.delete_bucket(bucket: @bucket)
  rescue Aws::S3::Errors::NoSuchBucket
    nil
  end

  test "syncing a bucket catalogues every object as a reference" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      assert_equal 3, Feed.files.count

      pdf = feed_at("invoices/march.pdf")
      assert_equal "application/pdf", pdf.mime
      assert_equal "march.pdf", pdf.title
      assert_equal @bucket, pdf.locator["bucket"]
      assert_equal @resource, pdf.resource

      assert_equal "image/jpeg", feed_at("photos/beach.jpg").mime
      assert_equal "text/plain", feed_at("notes.txt").mime
    end
  end

  test "syncing twice converges rather than accumulating" do
    2.times { Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) } }

    Tenant.switch(@tenant) { assert_equal 3, Feed.files.count }
  end

  test "a sync writes into one tenant only" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@other) { assert_equal 0, Feed.files.count }
  end

  test "the bytes are still in the resource, not in items" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      item = feed_at("notes.txt")

      assert_equal "contents of notes.txt", @resource.download(item.locator).read
    end
  end

  test "a first sync records the version the resource reports, and calls nothing changed" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      pdf = reference_at("invoices/march.pdf")

      assert pdf.version.present?
      assert_nil pdf.changed_at
    end
  end

  test "an object whose bytes moved is marked changed and queued for analysis again" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    was = Tenant.switch(@tenant) do
      reference_at("invoices/march.pdf").tap { |r| r.update!(analyzed_at: Time.current) }.version
    end

    put "invoices/march.pdf", body: "a corrected invoice"
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      pdf = reference_at("invoices/march.pdf")

      assert_not_equal was, pdf.version
      assert pdf.changed_at.present?
      assert_nil pdf.analyzed_at, "a changed file has not been analyzed since it changed"
    end
  end

  test "an object that did not move is not marked changed, however often it is synced" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) { reference_at("notes.txt").update!(analyzed_at: Time.current) }

    2.times { Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) } }

    Tenant.switch(@tenant) do
      notes = reference_at("notes.txt")

      assert_nil notes.changed_at
      assert notes.analyzed_at.present?, "an unchanged file is not analyzed again"
    end
  end

  test "an object is saved with the cursor its page began at, so a resumed sync misses none of that page" do
    pages = { nil => [ %w[a b], "b" ], "b" => [ %w[c d], "d" ] }
    paged = Object.new
    paged.define_singleton_method(:each_page) do |cursor:, &block|
      while (page = pages[cursor])
        block.call(*page)
        cursor = page.last
      end
    end

    job = SyncResourceJob.new(@tenant.id, @resource.id)
    job.define_singleton_method(:resource_for) { |_id| paged }

    walked = job.build_enumerator(@tenant.id, @resource.id, cursor: nil).to_a

    assert_equal [ [ "a", nil ], [ "b", "b" ], [ "c", "b" ], [ "d", "d" ] ], walked

    stopped_after = walked.index { |object, _| object == "c" }
    resumed = job.build_enumerator(@tenant.id, @resource.id, cursor: walked[stopped_after].last).to_a

    assert_equal %w[c d], resumed.map(&:first)
  end

  test "a resource that cannot report a version never claims anything changed" do
    versionless = Tenant.switch(@tenant) do
      Resource::Imap.new(key: "mail", details: {}, credentials: {})
    end

    assert_nil versionless.version_for(versionless.locator_for(
      Struct.new(:mailbox, :uidvalidity, :uid).new("INBOX", 1, 2)
    ))
  end

  private

    def put(key, body: nil)
      @resource.client.put_object(bucket: @bucket, key: key, body: body || "contents of #{key}")
    end

    def reference_at(locator_key)
      Reference.find_by!(resource_id: @resource.id, locator_key: locator_key)
    end
end
