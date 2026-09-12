require "test_helper"

class MediaAnalyzerTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "med-#{SecureRandom.hex(4)}", name: "Media")
    @bucket = "med-#{SecureRandom.hex(6)}"

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(
        key: @bucket,
        details: {
          "endpoint" => ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
          "region" => ENV.fetch("S3_REGION", "us-east-1")
        },
        credentials: {
          "access_key_id" => ENV.fetch("S3_ACCESS_KEY_ID", "uris"),
          "secret_access_key" => ENV.fetch("S3_SECRET_ACCESS_KEY", "urisuris")
        }
      )
    end

    @resource.client.create_bucket(bucket: @bucket)
    upload "tone.m4a"
    upload "clip.mp4"
    upload "standup.m4a"

    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }
  end

  teardown do
    ENV.delete("URIS_WHISPER_MODEL")

    @resource.client.list_objects_v2(bucket: @bucket).contents.each do |object|
      @resource.client.delete_object(bucket: @bucket, key: object.key)
    end
    @resource.client.delete_bucket(bucket: @bucket)
  rescue Aws::S3::Errors::NoSuchBucket
    nil
  end

  test "a recording is its own kind rather than an anonymous file" do
    assert_equal "audio/mpeg", MimeType.for_filename("standup.mp3")
    assert_equal "video/quicktime", MimeType.for_filename("demo.mov")

    Tenant.switch(@tenant) do
      assert_equal "audio/mp4", feed_at("tone.m4a").mime
      assert_equal "video/mp4", feed_at("clip.mp4").mime
    end
  end

  test "both kinds reach the media analyzer" do
    Tenant.switch(@tenant) do
      assert_instance_of Analyzer::Media, Analyzer.for(feed_at("tone.m4a"))
      assert_instance_of Analyzer::Media, Analyzer.for(feed_at("clip.mp4"))
    end
  end

  test "an audio file yields its length and its streams" do
    analyze_feed_at "tone.m4a"

    Tenant.switch(@tenant) do
      probe = steps_at("tone.m4a").dig("probe", "result")

      assert_in_delta 1.0, probe["duration"], 0.2
      assert_equal [ "audio" ], probe["streams"].map { |stream| stream["type"] }
      assert_equal 16_000, probe["streams"].first["sample_rate"]
    end
  end

  test "a video yields its picture as well as its sound" do
    analyze_feed_at "clip.mp4"

    Tenant.switch(@tenant) do
      streams = steps_at("clip.mp4").dig("probe", "result", "streams")
      video = streams.find { |stream| stream["type"] == "video" }

      assert_equal 160, video["width"]
      assert_equal 120, video["height"]
      assert_includes streams.map { |stream| stream["type"] }, "audio"
    end
  end

  test "with no model configured the recording is still catalogued, and says why it is silent" do
    ENV.delete("URIS_WHISPER_MODEL")

    analyze_feed_at "tone.m4a"

    Tenant.switch(@tenant) do
      steps = steps_at("tone.m4a")

      assert steps.dig("probe", "result").present?, "metadata does not need a model"
      assert_match(/URIS_WHISPER_MODEL/, steps.dig("transcript", "error", "message"))
      assert_equal "Analyzer::Failed", steps.dig("transcript", "error", "class")
    end
  end

  test "a model that was named but is not there is refused by name" do
    ENV["URIS_WHISPER_MODEL"] = "/tmp/there-is-no-such-model.bin"

    analyze_feed_at "tone.m4a"

    Tenant.switch(@tenant) do
      message = steps_at("tone.m4a").dig("transcript", "error", "message")

      assert_match(%r{/tmp/there-is-no-such-model\.bin}, message)
      assert_match(/not a file/, message)
    end
  end

  test "the length reaches the prompt, so a summary can say how long it runs" do
    analyze_feed_at "clip.mp4"

    Tenant.switch(@tenant) do
      analyzer = Analyzer::Media.new(feed_at("clip.mp4"), analysis: analysis_at("clip.mp4"))

      assert_match(/Length: 1 second/, analyzer.summary_prompt)
      assert_match(/video h264 160×120/, analyzer.summary_prompt)
    end
  end

  test "what was said becomes text, and the text becomes searchable" do
    requires_transcription!

    analyze_feed_at "standup.m4a"
    SearchIndex.refresh!

    Tenant.switch(@tenant) do
      transcript = steps_at("standup.m4a").dig("transcript", "result")

      assert_match(/invoice/i, transcript)
      assert_match(/4,200|4200/, transcript)

      assert_equal [ "standup.m4a" ], Feed.search("invoice", mime: "audio/mp4").pluck(:title),
                   "a spoken word is a searchable word or the transcript was for nothing"
    end
  end

  test "a recording with no sound in it is not silently reported as heard" do
    requires_transcription!

    @resource.client.put_object(
      bucket: @bucket, key: "silent.mp4",
      body: File.binread(Rails.root.join("test/fixtures/files/silent.mp4"))
    )

    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }
    analyze_feed_at "silent.mp4"

    Tenant.switch(@tenant) do
      steps = steps_at("silent.mp4")

      assert steps.dig("probe", "result").present?
      assert_match(/carries no audio/, steps.dig("transcript", "error", "message"))
    end
  end

  test "a video has a poster, and an audio file does not pretend to" do
    assert Thumbnail.available_for?("video/mp4")
    assert_not Thumbnail.available_for?("audio/mp4")

    Tenant.switch(@tenant) do
      bytes = Thumbnail.for(reference_at("clip.mp4"), size: "medium")

      assert bytes.bytesize.positive?
      assert_equal "\xFF\xD8".b, bytes[0, 2].b, "a jpeg, not whatever ffmpeg felt like"
    end
  end
end
