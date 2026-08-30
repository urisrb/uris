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
          "access_key_id" => ENV.fetch("S3_ACCESS_KEY_ID", "things"),
          "secret_access_key" => ENV.fetch("S3_SECRET_ACCESS_KEY", "thingsthings")
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
      assert_equal 3, Thing.count

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

    Tenant.switch(@tenant) { assert_equal 3, Thing.count }
  end

  test "a sync writes into one tenant only" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@other) { assert_equal 0, Thing.count }
  end

  test "the bytes are still in the resource, not in things" do
    SyncResourceJob.perform_now(@tenant.id, @resource.id)

    Tenant.switch(@tenant) do
      thing = thing_at("notes.txt")

      assert_equal "contents of notes.txt", @resource.download(thing.locator).read
    end
  end

  private

    def put(key)
      @resource.client.put_object(bucket: @bucket, key: key, body: "contents of #{key}")
    end
end
