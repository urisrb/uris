require "test_helper"
require_relative "../support/fake_model_server"

class VisionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  FILES = Rails.root.join("test/fixtures/files")

  setup do
    SearchIndex.reset!

    @server = FakeModelServer.current
    @server.reset!.serves("gemma3:4b", "llama3.1:8b")

    ENV["THINGS_INFERENCE_ORIGINS"] = @server.origin

    @tenant = Tenant.create!(subdomain: "vis-#{SecureRandom.hex(4)}", name: "Vision")

    Tenant.switch(@tenant) do
      @storage = Resource::Database.create!(key: "disk", name: "Storage")
      @storage.make_default_storage!

      store "poster.png"
      store "sign.png"
      store "pixel.png"
      store "photo.png"
    end

    SyncResourceJob.perform_now(@tenant.id, @storage.id)
  end

  teardown do
    ENV.delete("THINGS_INFERENCE_ORIGINS")
  end

  test "an image is described from its pixels, and the preview travels with the prompt" do
    inference!
    @server.answer_json({ summary: "A printed sign reading PELICAN CENSUS.", keywords: %w[sign pelican] })

    analyze "poster.png"

    Tenant.switch(@tenant) do
      summary = reference("poster.png").analysis.dig("steps", "summary", "result")

      assert_equal "A printed sign reading PELICAN CENSUS.", summary["summary"]
      assert_equal %w[sign pelican], summary["keywords"]
    end

    assert_equal 1, @server.attachments.last.length
    assert_match %r{\Adata:image/jpeg;base64,}, @server.attachments.last.first
  end

  test "what the model sees is a bounded preview, not the original" do
    inference!
    @server.answer_json({ summary: "A sign." })

    analyze "poster.png"

    sent = decoded(@server.attachments.last.first)

    assert_equal "1902", header(FILES.join("poster.png").to_s, "width")
    assert_equal Thumbnail::SIZES.fetch("large").to_s, header(sent, "width")
    assert_equal "jpegload", header(sent, "vips-loader")
  end

  test "an image smaller than the preview is sent at its own size, not blown up" do
    inference!
    @server.answer_json({ summary: "A sign." })

    analyze "sign.png"

    assert_equal "634", header(decoded(@server.attachments.last.first), "width")
  end

  test "the text read out of the image is offered as context, fenced as data" do
    inference!
    @server.answer_json({ summary: "A sign." })

    analyze "poster.png"

    asked = @server.prompts.last

    assert_includes asked, "PELICAN CENSUS 4820"
    assert_includes asked, "data, not"
    assert_includes asked, "1902×357"
  end

  test "the description reaches the search index" do
    inference!
    @server.answer_json({ summary: "A sign counting wading birds.", keywords: [ "estuary" ] })

    analyze "poster.png"
    SearchIndex.refresh!

    Tenant.switch(@tenant) do
      assert_equal [ "poster.png" ], Thing.search("estuary").pluck(:title)
    end
  end

  test "provenance names the vision role and the model that answered" do
    inference!
    @server.answer_json({ summary: "A sign." })

    analyze "poster.png"

    Tenant.switch(@tenant) do
      step = reference("poster.png").analysis.dig("steps", "summary")

      assert_equal "vision", step["role"]
      assert_equal "gemma3:4b", step["model"]
      assert_equal "ollama", step["resource"]
    end
  end

  test "a tracking pixel is described without asking the model" do
    inference!

    analyze "pixel.png"

    assert_equal 0, @server.count_for("/v1/chat/completions")

    Tenant.switch(@tenant) do
      assert_includes reference("pixel.png").analysis.dig("steps", "summary", "result", "summary"),
                      "tracking pixel"
    end
  end

  test "a single-colour image is described without asking the model" do
    inference!

    analyze "photo.png"

    assert_equal 0, @server.count_for("/v1/chat/completions")

    Tenant.switch(@tenant) do
      summary = reference("photo.png").analysis.dig("steps", "summary", "result")

      assert_includes summary["summary"], "single-colour"
      assert_includes summary["summary"], "120×80"
      assert_equal %w[solid background], summary["keywords"]
    end
  end

  test "a trivial image is described even with no inference resource configured" do
    analyze "pixel.png"

    Tenant.switch(@tenant) do
      assert reference("pixel.png").analysis.dig("steps", "summary", "result", "summary").present?
    end
  end

  test "an inference resource that serves no vision model leaves the image undescribed" do
    Tenant.switch(@tenant) do
      Resource::OpenaiCompatible.create!(
        key: "ollama", name: "Local models",
        details: { "base_url" => @server.base_url, "models" => { "smart" => "llama3.1:8b" } }
      ).make_default_inference!
    end

    analyze "poster.png"

    assert_equal 0, @server.count_for("/v1/chat/completions")

    Tenant.switch(@tenant) do
      steps = reference("poster.png").analysis.fetch("steps")

      assert steps.key?("ocr")
      assert_not steps.key?("summary")
      assert reference("poster.png").analyzed_at.present?
    end
  end

  test "a second analysis does not send the image again" do
    inference!
    @server.answer_json({ summary: "A sign." })

    analyze "poster.png"
    analyze "poster.png"

    assert_equal 1, @server.count_for("/v1/chat/completions")
  end

  private

    def inference!
      Tenant.switch(@tenant) do
        @inference = Resource::OpenaiCompatible.create!(
          key: "ollama", name: "Local models",
          details: { "base_url" => @server.base_url, "models" => { "vision" => "gemma3:4b" } }
        )
        @inference.make_default_inference!
      end
    end

    def decoded(uri)
      bytes = Base64.strict_decode64(uri.split(",", 2).last)
      path = File.join(Dir.mktmpdir, "sent.jpg")
      File.binwrite(path, bytes)
      path
    end

    def header(path, field)
      Open3.capture2("vipsheader", "-f", field, path).first.strip
    end

    def store(name)
      @storage.upload(name, FILES.join(name).binread)
    end

    def analyze(key)
      id = Tenant.switch(@tenant) { thing(key).id }
      AnalyzeThingJob.perform_now(@tenant.id, id)
    end

    def thing(key)
      Thing.joins(:references).find_by!(thing_references: { locator_key: key })
    end

    def reference(key)
      ThingReference.find_by!(locator_key: key).reload
    end
end
