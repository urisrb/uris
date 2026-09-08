require "test_helper"

class ReferenceTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "ref-#{SecureRandom.hex(4)}", name: "References")

    Tenant.switch(@tenant) do
      @s3 = Resource::S3.create!(key: "bucket", details: { "endpoint" => "http://127.0.0.1:1" })
      @drive = Resource::S3.create!(key: "drive", details: { "endpoint" => "http://127.0.0.1:1" })
    end
  end

  test "a reference can move to another feed, and an emptied one does not survive it" do
    Tenant.switch(@tenant) do
      one = create_feed(mime: "application/pdf", title: "One", resource: @s3, locator_key: "one.pdf")
      two = create_feed(mime: "application/pdf", title: "Two", resource: @drive, locator_key: "two.pdf")

      two.references.first.move_to!(one)

      assert_equal 2, one.references.reset.count
      assert_nil Feed.find_by(id: two.id), "a file with no references is not a thing"
    end
  end

  test "moving onto a feed that already holds the same place keeps one reference" do
    Tenant.switch(@tenant) do
      keep = create_feed(mime: "application/pdf", title: "Keep", resource: @s3, locator_key: "same.pdf")
      other = Feed.create!(type: Feed::FILE, key: "Other", title: "Other")
      moved = other.references.create!(resource: @drive, locator_key: "same.pdf")

      moved.move_to!(keep)

      assert_equal 2, keep.references.reset.count, "a different resource is a different place"
    end
  end

  test "splitting a reference off gives it a feed of its own" do
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

  test "a reference records the mime it was discovered with" do
    Tenant.switch(@tenant) do
      reference = Reference.discover!(resource: @s3, locator: { "key" => "photos/beach.jpg" },
                                      locator_key: "photos/beach.jpg", title: "beach.jpg")

      assert_equal "image/jpeg", reference.mime
      assert_equal "beach.jpg", reference.feed.title
      assert_equal Reference::ORIGINAL, reference.role
    end
  end

  test "destroying a feed takes its references with it" do
    Tenant.switch(@tenant) do
      feed = create_feed(mime: "application/pdf", title: "Doomed", resource: @s3, locator_key: "x.pdf")

      assert_difference -> { Reference.count }, -1 do
        feed.destroy!
      end
    end
  end
end
