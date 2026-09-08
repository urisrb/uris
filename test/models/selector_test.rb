require "test_helper"

class SelectorTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "select-#{SecureRandom.hex(4)}", name: "Selector")

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(key: "bucket", details: { "endpoint" => "http://127.0.0.1:1" })

      @march = place("2024/invoices/march.pdf", at: 3.days.ago)
      @april = place("2024/invoices/april.pdf", at: 2.days.ago)
      @note = place("2024/notes/scratch.txt", kind: "text", at: 1.day.ago)
      @root = place("readme.txt", kind: "text", at: 1.hour.ago)
    end
  end

  def place(key, kind: "pdf", at: Time.current)
    item = Feed.create!(kind: kind, title: File.basename(key), created_at: at)
    Reference.create!(item: item, resource: @resource, locator_key: key, locator: {})
    item
  end

  def matching(**selector)
    Tenant.switch(@tenant) { Feed.matching(selector).order(:id).to_a }
  end

  test "a folder is a prefix of the locator key, and it does not match a sibling by accident" do
    assert_equal [ @march, @april, @note ], matching(folder: "2024")
    assert_equal [ @march, @april ], matching(folder: "2024/invoices")
    assert_equal [ @march, @april ], matching(folder: "/2024/invoices/")
  end

  test "a folder does not match a longer name that merely starts the same way" do
    Tenant.switch(@tenant) { @sibling = place("2024/invoices-archive/old.pdf") }

    assert_equal [ @march, @april ], matching(folder: "2024/invoices")
    assert_includes matching(folder: "2024"), @sibling
  end

  test "a folder narrows with a kind rather than replacing it" do
    assert_equal [ @note ], matching(folder: "2024", kind: "text")
  end

  test "since and before bound the catalog by when an item was catalogued" do
    assert_equal [ @note, @root ], matching(since: 36.hours.ago.iso8601)
    assert_equal [ @march, @april ], matching(before: 36.hours.ago.iso8601)
    assert_equal [ @note ], matching(since: 36.hours.ago.iso8601, before: 90.minutes.ago.iso8601)
  end

  test "a date that is not a date is refused rather than quietly matching everything" do
    assert_raises(ArgumentError) { matching(since: "the day before yesterday") }
  end

  test "an empty selector is the whole catalog, which is what widens an export" do
    assert_equal 4, matching.length
  end

  test "a folder nothing lives under matches nothing rather than everything" do
    assert_empty matching(folder: "2025")
  end
end
