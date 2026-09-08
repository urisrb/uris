require "test_helper"

class MergeTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "merge-#{SecureRandom.hex(4)}", name: "Merging")

    Tenant.switch(@tenant) do
      @s3 = Resource::S3.create!(key: "bucket", details: { "endpoint" => "http://127.0.0.1:1" })
      @drive = Resource::S3.create!(key: "drive", details: { "endpoint" => "http://127.0.0.1:1" })
    end
  end

  test "one document in two places is one item with two references" do
    Tenant.switch(@tenant) do
      pdf = create_feed(mime: "application/pdf", title: "Contract", resource: @s3, locator_key: "contract.pdf")
      link = create_feed(mime: "application/pdf", title: "Contract", resource: @drive, locator_key: "Contract")

      pdf.merge!(link)

      assert_equal 2, pdf.references.count
      assert_equal [ "drive", "bucket" ].sort, pdf.references.map { |r| r.resource.key }.sort
      assert_nil Feed.find_by(id: link.id)
    end
  end

  test "a merge is a move, so nothing is left pointing at the other item" do
    Tenant.switch(@tenant) do
      keep = create_feed(mime: "application/pdf", title: "Keep", resource: @s3, locator_key: "a.pdf")
      gone = create_feed(mime: "application/pdf", title: "Gone", resource: @drive, locator_key: "b.pdf")
      moved = gone.references.first

      keep.merge!(gone)

      assert_equal keep.id, moved.reload.feed_id
      assert_empty Feed.where(id: gone.id)
      assert_equal 0, Reference.where(feed_id: gone.id).count
    end
  end

  test "a reference can move to any item, which is all a merge is" do
    Tenant.switch(@tenant) do
      one = create_feed(mime: "application/pdf", title: "One", resource: @s3, locator_key: "one.pdf")
      two = create_feed(mime: "application/pdf", title: "Two", resource: @drive, locator_key: "two.pdf")

      two.references.first.move_to!(one)

      assert_equal 2, one.references.reset.count
      assert_nil Feed.find_by(id: two.id), "an item with no references is not an item"
    end
  end

  test "splitting a reference off gives it an item of its own" do
    Tenant.switch(@tenant) do
      grouped = create_feed(mime: "application/pdf", title: "Grouped", resource: @s3, locator_key: "a.pdf")
      grouped.references.create!(resource: @drive, locator_key: "b.pdf")
      grouped.references.reset

      split = grouped.references.last.split!

      assert_not_equal grouped.id, split.feed_id
      assert_equal 1, grouped.references.reset.count
      assert_equal 1, split.feed.references.count
    end
  end

  test "merging the same place twice keeps one reference, not a duplicate" do
    Tenant.switch(@tenant) do
      keep = create_feed(mime: "application/pdf", title: "Keep", resource: @s3, locator_key: "same.pdf")
      other = Feed.create!(type: Feed::FILE, key: "Other", title: "Other")
      other.references.create!(resource: @drive, locator_key: "same.pdf")

      keep.merge!(other)

      assert_equal 2, keep.references.reset.count
    end
  end

  test "a merge carries the passes made over the absorbed copy rather than deleting them" do
    kept = nil

    Tenant.switch(@tenant) do
      one = create_feed(mime: "application/pdf", title: "One", resource: @s3, locator_key: "one.pdf")
      two = create_feed(mime: "application/pdf", title: "Two", resource: @drive, locator_key: "two.pdf")

      extracted(one, "kingfisher")
      extracted(two, "salamander")

      kept = one.merge!(two)
    end

    SearchIndex.refresh!

    Tenant.switch(@tenant) do
      assert_equal 2, kept.analyses.count, "a pass over either copy was a pass over one thing"
      assert_equal [ kept.id ], Feed.search("salamander").ids,
                   "the newest pass over the merged feed is what search reads"
    end
  end

  def extracted(feed, text)
    analysis = Analysis.open!(feed: feed, cause: "manual")
    analysis.write_step!("text", { "result" => text })
    analysis.finished!
    analysis
  end

  test "destroying an item takes its references with it" do
    Tenant.switch(@tenant) do
      item = create_feed(mime: "application/pdf", title: "Doomed", resource: @s3, locator_key: "x.pdf")

      assert_difference -> { Reference.count }, -1 do
        item.destroy!
      end
    end
  end
end
