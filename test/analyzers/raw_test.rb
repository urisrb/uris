require "test_helper"
require_relative "../support/fake_model_server"

class RawTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CORPUS = Rails.root.join("test/fixtures/corpus/image")

  test "a camera raw is an image, whatever the camera called it" do
    assert_equal "image", Kind.for_filename("DSC_0001.NEF")
    assert_equal "image", Kind.for_filename("IMG_4820.cr3")
    assert_equal "image", Kind.for_filename("holiday/P1000123.rw2")

    assert Kind.raw?("DSC_0001.nef")
    assert_not Kind.raw?("photo.jpg")
    assert_not Kind.raw?("notes.txt")
  end

  test "a raw is described from the picture inside it, not the thumbnail vips finds first" do
    source = CORPUS.join("photo.nef")
    skip "no corpus on disk — see test/fixtures/corpus/README.md" unless source.exist?

    SearchIndex.reset!

    server = FakeModelServer.current
    server.reset!.serves("gemma3:4b")
    ENV["THINGS_INFERENCE_ORIGINS"] = server.origin

    tenant = Tenant.create!(subdomain: "raw-#{SecureRandom.hex(4)}", name: "Raw")

    Tenant.switch(tenant) do
      storage = Resource::Database.create!(key: "disk", name: "Storage")
      storage.make_default_storage!
      storage.upload("photo.nef", source.binread)

      Resource::OpenaiCompatible.create!(
        key: "ollama", name: "Local models",
        details: { "base_url" => server.base_url, "models" => { "vision" => "gemma3:4b" } }
      ).make_default_inference!

      SyncResourceJob.perform_now(tenant.id, storage.id)
    end

    server.answer_json({ summary: "A photograph off a Nikon.", keywords: [ "photograph" ] })

    id = Tenant.switch(tenant) do
      Thing.joins(:references).find_by!(thing_references: { locator_key: "photo.nef" }).id
    end
    AnalyzeThingJob.perform_now(tenant.id, id)

    Tenant.switch(tenant) do
      reference = ThingReference.find_by!(locator_key: "photo.nef").reload
      dimensions = reference.analysis.dig("steps", "dimensions", "result")

      assert_equal "image", reference.kind
      assert_operator dimensions["width"], :>=, Raw::MINIMUM
      assert_equal "A photograph off a Nikon.",
                   reference.analysis.dig("steps", "summary", "result", "summary")
    end

    sent = Base64.strict_decode64(server.attachments.last.first.split(",", 2).last)
    path = File.join(Dir.mktmpdir, "sent.jpg")
    File.binwrite(path, sent)

    assert_equal Thumbnail::SIZES.fetch("large").to_s,
                 Open3.capture2("vipsheader", "-f", "width", path).first.strip
  ensure
    ENV.delete("THINGS_INFERENCE_ORIGINS")
  end
end
