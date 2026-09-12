require "test_helper"

class PlacementTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "place-#{SecureRandom.hex(4)}", name: "Placement")

    Tenant.switch(@tenant) do
      @default = Resource::Database.create!(key: "shelf", name: "Shelf")
      @default.make_default_storage!
      @archive = Resource::Database.create!(key: "archive", name: "Archive")
    end
  end

  test "a staged file is placed where it was told, with the reason, and the staged copy goes" do
    Tenant.switch(@tenant) do
      feed = staged("receipts/march.txt", "paid")
      analysis = Analysis.open!(feed: feed, cause: "upload")

      reference = Placement.new(feed, analysis: analysis).place!(@archive, reason: "it is a receipt")

      assert_equal @archive, reference.resource
      assert_equal "receipts/march.txt", reference.locator_key
      assert_equal "paid", reference.download.read
      assert_not feed.reload.staged?
      assert_equal 0, ActiveStorage::Blob.count
      assert_equal({ "resource" => "archive", "path" => "receipts/march.txt", "by" => "agent",
                     "reason" => "it is a receipt" }, analysis.reload.step_result("placement"))
    end
  end

  test "a place that does not accept the file is refused and the file stays staged" do
    Tenant.switch(@tenant) do
      feed = staged("march.txt", "paid")
      children = Resource.internal!(:children)

      assert_raises(Placement::Refused) { Placement.new(feed).place!(children, reason: "why not") }
      assert feed.reload.staged?
    end
  end

  test "an archived store is not a candidate" do
    Tenant.switch(@tenant) do
      feed = staged("march.txt", "paid")
      @archive.update!(archived_at: Time.current)

      assert_equal [ "shelf" ], Placement.candidates(feed).pluck(:key)
    end
  end

  test "a path another feed already holds there is not overwritten" do
    Tenant.switch(@tenant) do
      first = staged("march.txt", "first")
      Placement.new(first).place!(@default, reason: "first")

      second = Feed.create!(type: Feed::FILE, key: "march.txt", title: "march.txt")
      Staged.stage!(second, path: "march.txt", body: "second", mime: "text/plain")
      reference = Placement.new(second).place!(@default, reason: "second")

      assert_equal "march-#{second.id}.txt", reference.locator_key
      assert_equal "first", first.reference.download.read
    end
  end

  test "settling places what nobody placed in default storage, and leaves a placed file alone" do
    Tenant.switch(@tenant) do
      feed = staged("march.txt", "paid")

      assert_equal @default, Placement.new(feed).settled!.resource
      assert_nil Placement.new(feed).settled!
    end
  end

  test "settling with nowhere to go says so and keeps the file staged" do
    Tenant.switch(@tenant) do
      feed = staged("march.txt", "paid")
      Resource.update_all(archived_at: Time.current)

      assert_raises(Placement::Nowhere) { Placement.new(feed).settled! }
      assert feed.reload.staged?
    end
  end

  test "where a file was put is not part of what it says, so search does not find it by its shelf" do
    Tenant.switch(@tenant) do
      feed = staged("receipts/march.txt", "paid")
      analysis = Analysis.open!(feed: feed, cause: "upload")

      Placement.new(feed, analysis: analysis).place!(@archive, reason: "it is a receipt")

      assert_empty analysis.reload.extracted
    end
  end

  test "the analysis reads a staged file before it has a reference" do
    Tenant.switch(@tenant) do
      feed = staged("march.txt", "the March rent is paid")
      analysis = Analysis.open!(feed: feed, cause: "upload")

      Analyzer.for(feed, analysis: analysis).run

      assert_equal "the March rent is paid", analysis.reload.step_result("text")
      assert_not_nil feed.analyzed_at
    end
  end

  private

    def staged(path, body)
      feed = Feed.create!(type: Feed::FILE, key: File.basename(path), title: File.basename(path))
      Staged.stage!(feed, path: path, body: body, mime: MimeType.for_filename(path))
      feed
    end
end
