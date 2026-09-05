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
      pdf = create_item(kind: "pdf", title: "Contract", resource: @s3, locator_key: "contract.pdf")
      link = create_item(kind: "pdf", title: "Contract", resource: @drive, locator_key: "Contract")

      pdf.merge!(link)

      assert_equal 2, pdf.references.count
      assert_equal [ "drive", "bucket" ].sort, pdf.references.map { |r| r.resource.key }.sort
      assert_nil Item.find_by(id: link.id)
    end
  end

  test "a merge is a move, so nothing is left pointing at the other item" do
    Tenant.switch(@tenant) do
      keep = create_item(kind: "pdf", title: "Keep", resource: @s3, locator_key: "a.pdf")
      gone = create_item(kind: "pdf", title: "Gone", resource: @drive, locator_key: "b.pdf")
      moved = gone.references.first

      keep.merge!(gone)

      assert_equal keep.id, moved.reload.item_id
      assert_empty Item.where(id: gone.id)
      assert_equal 0, Reference.where(item_id: gone.id).count
    end
  end

  test "a reference can move to any item, which is all a merge is" do
    Tenant.switch(@tenant) do
      one = create_item(kind: "pdf", title: "One", resource: @s3, locator_key: "one.pdf")
      two = create_item(kind: "pdf", title: "Two", resource: @drive, locator_key: "two.pdf")

      two.references.first.move_to!(one)

      assert_equal 2, one.references.reset.count
      assert_nil Item.find_by(id: two.id), "a item with no references is not a item"
    end
  end

  test "splitting a reference off gives it a item of its own" do
    Tenant.switch(@tenant) do
      grouped = create_item(kind: "pdf", title: "Grouped", resource: @s3, locator_key: "a.pdf")
      grouped.references.create!(resource: @drive, locator_key: "b.pdf")
      grouped.references.reset

      split = grouped.references.last.split!

      assert_not_equal grouped.id, split.item_id
      assert_equal 1, grouped.references.reset.count
      assert_equal 1, split.item.references.count
    end
  end

  test "merging the same place twice keeps one reference, not a duplicate" do
    Tenant.switch(@tenant) do
      keep = create_item(kind: "pdf", title: "Keep", resource: @s3, locator_key: "same.pdf")
      other = Item.create!(kind: "pdf", title: "Other")
      other.references.create!(resource: @drive, locator_key: "same.pdf")

      keep.merge!(other)

      assert_equal 2, keep.references.reset.count
    end
  end

  test "a merged item carries the analysis of every reference into search" do
    kept = nil

    Tenant.switch(@tenant) do
      one = create_item(kind: "pdf", title: "One", resource: @s3, locator_key: "one.pdf")
      two = create_item(kind: "pdf", title: "Two", resource: @drive, locator_key: "two.pdf")

      one.references.first.update!(analysis: { "steps" => { "text" => { "result" => "kingfisher" } } })
      two.references.first.update!(analysis: { "steps" => { "text" => { "result" => "salamander" } } })

      kept = one.merge!(two)
    end

    SearchIndex.refresh!

    Tenant.switch(@tenant) do
      assert_equal [ kept.id ], Item.search("kingfisher").ids
      assert_equal [ kept.id ], Item.search("salamander").ids,
                   "extraction from the merged-in reference survived the merge"
    end
  end

  test "destroying a item takes its references with it" do
    Tenant.switch(@tenant) do
      item = create_item(kind: "pdf", title: "Doomed", resource: @s3, locator_key: "x.pdf")

      assert_difference -> { Reference.count }, -1 do
        item.destroy!
      end
    end
  end
end
