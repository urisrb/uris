require "test_helper"

class AnalyzerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "ana-#{SecureRandom.hex(4)}", name: "Analysis")
    @bucket = "ana-#{SecureRandom.hex(6)}"

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(
        key: @bucket,
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
    upload "invoice.pdf"
    upload "photo.png"
    @resource.client.put_object(bucket: @bucket, key: "notes.txt", body: "remember the milk")
    @resource.client.put_object(bucket: @bucket, key: "rows.csv", body: "name,amount\nash,10\nbea,20\n")

    SyncResourceJob.perform_now(@tenant.id, @resource.id)
  end

  teardown do
    @resource.client.list_objects_v2(bucket: @bucket).contents.each do |object|
      @resource.client.delete_object(bucket: @bucket, key: object.key)
    end
    @resource.client.delete_bucket(bucket: @bucket)
  rescue Aws::S3::Errors::NoSuchBucket
    nil
  end

  test "dispatch picks an analyzer by kind, first match wins" do
    Tenant.switch(@tenant) do
      assert_instance_of Analyzer::Pdf, Analyzer.for(item("invoice.pdf"))
      assert_instance_of Analyzer::Image, Analyzer.for(item("photo.png"))
      assert_instance_of Analyzer::Text, Analyzer.for(item("notes.txt"))
      assert_instance_of Analyzer::Data, Analyzer.for(item("rows.csv"))
    end
  end

  test "a pdf yields its text and page count" do
    analyze "invoice.pdf"

    Tenant.switch(@tenant) do
      analysis = reference("invoice.pdf").analysis

      assert_includes analysis.dig("steps", "text", "result"), "Invoice for March"
      assert_equal "1", analysis.dig("steps", "info", "result", "pages")
    end
  end

  test "an image yields its dimensions" do
    analyze "photo.png"

    Tenant.switch(@tenant) do
      dimensions = reference("photo.png").analysis.dig("steps", "dimensions", "result")

      assert_equal 120, dimensions["width"]
      assert_equal 80, dimensions["height"]
    end
  end

  test "a csv yields its columns and row count" do
    analyze "rows.csv"

    Tenant.switch(@tenant) do
      shape = reference("rows.csv").analysis.dig("steps", "shape", "result")

      assert_equal %w[name amount], shape["columns"]
      assert_equal 2, shape["rows"]
    end
  end

  test "a completed step is not recomputed" do
    analyze "notes.txt"

    Tenant.switch(@tenant) do
      subject = item("notes.txt")
      first_finished = reference("notes.txt").analysis.dig("steps", "text", "finished_at")

      Analyzer.for(subject).run

      assert_equal first_finished, reference("notes.txt").analysis.dig("steps", "text", "finished_at")
    end
  end

  test "force recomputes a step" do
    analyze "notes.txt"

    Tenant.switch(@tenant) do
      subject = item("notes.txt")
      analyzer = Analyzer.for(subject)
      before = reference("notes.txt").analysis.dig("steps", "text", "finished_at")

      analyzer.run
      analyzer.step(:text, force: true) { "different" }

      after = reference("notes.txt").analysis

      assert_not_equal before, after.dig("steps", "text", "finished_at")
      assert_equal "different", after.dig("steps", "text", "result")
    end
  end

  test "a step computed before the bytes moved is computed again" do
    analyze "notes.txt"

    before = Tenant.switch(@tenant) { reference("notes.txt").analysis.dig("steps", "text") }

    @resource.client.put_object(bucket: @bucket, key: "notes.txt", body: "buy more milk")
    SyncResourceJob.perform_now(@tenant.id, @resource.id)
    analyze "notes.txt"

    Tenant.switch(@tenant) do
      after = reference("notes.txt").analysis.dig("steps", "text")

      assert_equal "remember the milk", before["result"]
      assert_equal "buy more milk", after["result"]
      assert_not_equal before["finished_at"], after["finished_at"]
    end
  end

  test "a step computed after the bytes moved is left alone" do
    @resource.client.put_object(bucket: @bucket, key: "notes.txt", body: "buy more milk")
    SyncResourceJob.perform_now(@tenant.id, @resource.id)
    analyze "notes.txt"

    finished = Tenant.switch(@tenant) do
      reference("notes.txt").analysis.dig("steps", "text", "finished_at")
    end

    analyze "notes.txt"

    Tenant.switch(@tenant) do
      assert_equal finished, reference("notes.txt").analysis.dig("steps", "text", "finished_at")
    end
  end

  test "syncing enqueues analysis again for the item whose bytes moved, and only that one" do
    %w[invoice.pdf photo.png notes.txt rows.csv].each { |key| analyze key }

    @resource.client.put_object(bucket: @bucket, key: "notes.txt", body: "buy more milk")

    assert_enqueued_jobs 1, only: AnalyzeItemJob do
      SyncResourceJob.perform_now(@tenant.id, @resource.id)
    end
  end

  test "extracted text becomes searchable" do
    analyze "invoice.pdf"
    SearchIndex.refresh!

    Tenant.switch(@tenant) do
      assert_equal [ "invoice.pdf" ], Item.search("totalling").pluck(:title)
    end
  end

  test "syncing enqueues analysis for each new item" do
    Tenant.switch(@tenant) { Item.destroy_all }

    assert_enqueued_jobs 4, only: AnalyzeItemJob do
      SyncResourceJob.perform_now(@tenant.id, @resource.id)
    end
  end

  private

    def upload(name)
      @resource.client.put_object(
        bucket: @bucket, key: name,
        body: File.binread(Rails.root.join("test/fixtures/files", name))
      )
    end

    def item(key)
      item_at(key)
    end

    def reference(key)
      Reference.find_by!(locator_key: key).reload
    end

    def analyze(key)
      id = Tenant.switch(@tenant) { item(key).id }
      AnalyzeItemJob.perform_now(@tenant.id, id)
    end
end
