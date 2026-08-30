require "test_helper"

class ExportThingsJobTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "exp-#{SecureRandom.hex(4)}", name: "Export")
    @source_bucket = "src-#{SecureRandom.hex(6)}"
    @destination_bucket = "dst-#{SecureRandom.hex(6)}"

    Tenant.switch(@tenant) do
      @source = build_resource(@source_bucket, "Source")
      @destination = build_resource(@destination_bucket, "Backup")
    end

    @source.client.create_bucket(bucket: @source_bucket)
    @destination.client.create_bucket(bucket: @destination_bucket)

    put @source, "invoices/march.pdf"
    put @source, "photos/beach.jpg"

    SyncResourceJob.perform_now(@tenant.id, @source.id)
    SearchIndex.refresh!
  end

  teardown do
    [ [ @source, @source_bucket ], [ @destination, @destination_bucket ] ].each do |resource, bucket|
      resource.client.list_objects_v2(bucket: bucket).contents.each do |object|
        resource.client.delete_object(bucket: bucket, key: object.key)
      end
      resource.client.delete_bucket(bucket: bucket)
    rescue Aws::S3::Errors::NoSuchBucket
      nil
    end
  end

  test "everything in the catalog reaches the destination resource" do
    ExportThingsJob.perform_now(@tenant.id, @destination.id, {})

    assert_equal [
      "#{@source_bucket}/invoices/march.pdf",
      "#{@source_bucket}/photos/beach.jpg"
    ].sort, exported_keys
  end

  test "the bytes arrive intact" do
    ExportThingsJob.perform_now(@tenant.id, @destination.id, {})

    body = @destination.client.get_object(
      bucket: @destination_bucket, key: "#{@source_bucket}/invoices/march.pdf"
    ).body.read

    assert_equal "contents of invoices/march.pdf", body
  end

  test "a selector narrows what is exported" do
    ExportThingsJob.perform_now(@tenant.id, @destination.id, { "kind" => "image" })

    assert_equal [ "#{@source_bucket}/photos/beach.jpg" ], exported_keys
  end

  test "a search query is a selector too" do
    ExportThingsJob.perform_now(@tenant.id, @destination.id, { "query" => "march" })

    assert_equal [ "#{@source_bucket}/invoices/march.pdf" ], exported_keys
  end

  test "exporting moves bytes without cataloguing them" do
    assert_no_difference -> { Tenant.switch(@tenant) { Thing.count } } do
      ExportThingsJob.perform_now(@tenant.id, @destination.id, {})
    end
  end

  private

    def build_resource(bucket, name)
      Resource::S3.create!(
        key: bucket,
        name: name,
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

    def put(resource, key)
      resource.client.put_object(bucket: resource.bucket, key: key, body: "contents of #{key}")
    end

    def exported_keys
      @destination.client.list_objects_v2(bucket: @destination_bucket).contents.map(&:key).sort
    end
end
