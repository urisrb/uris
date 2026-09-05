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
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@tenant) do
      assert_equal 3, Item.count

      pdf = thing_at("invoices/march.pdf")
      assert_equal "pdf", pdf.kind
      assert_equal "march.pdf", pdf.title
      assert_equal @bucket, pdf.locator["bucket"]
      assert_equal @resource, pdf.resource

      assert_equal "image", thing_at("photos/beach.jpg").kind
      assert_equal "text", thing_at("notes.txt").kind
    end
  end

  test "syncing twice converges rather than accumulating" do
    2.times { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) { assert_equal 3, Item.count }
  end

  test "a sync writes into one tenant only" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@other) { assert_equal 0, Item.count }
  end

  test "the bytes are still in the resource, not in items" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@tenant) do
      item = thing_at("notes.txt")

      assert_equal "contents of notes.txt", @resource.download(item.locator).read
    end
  end

  test "a first sync records the version the resource reports, and calls nothing changed" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@tenant) do
      pdf = reference_at("invoices/march.pdf")

      assert pdf.version.present?
      assert_nil pdf.changed_at
    end
  end

  test "an object whose bytes moved is marked changed and queued for analysis again" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    was = Tenant.switch(@tenant) do
      reference_at("invoices/march.pdf").tap { |r| r.update!(analyzed_at: Time.current) }.version
    end

    put "invoices/march.pdf", body: "a corrected invoice"
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@tenant) do
      pdf = reference_at("invoices/march.pdf")

      assert_not_equal was, pdf.version
      assert pdf.changed_at.present?
      assert_nil pdf.analyzed_at, "a changed file has not been analyzed since it changed"
    end
  end

  test "an object that did not move is not marked changed, however often it is synced" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@tenant) { reference_at("notes.txt").update!(analyzed_at: Time.current) }

    2.times { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      notes = reference_at("notes.txt")

      assert_nil notes.changed_at
      assert notes.analyzed_at.present?, "an unchanged file is not analyzed again"
    end
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
