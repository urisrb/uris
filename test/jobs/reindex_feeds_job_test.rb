require "test_helper"

class ReindexItemsJobTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "reix-#{SecureRandom.hex(4)}", name: "Reindex")
    @other = Tenant.create!(subdomain: "othr-#{SecureRandom.hex(4)}", name: "Other")

    Tenant.switch(@tenant) do
      create_item(kind: "pdf", title: "March invoice", locator_key: "invoices/march.pdf")
      create_item(kind: "image", title: "Beach photo", locator_key: "photos/beach.jpg")
    end

    Tenant.switch(@other) do
      create_item(kind: "pdf", title: "Acme invoice", locator_key: "invoices/acme.pdf")
    end

    SearchIndex.refresh!
  end

  def reindex(tenant = @tenant, index: nil)
    run = Tenant.switch(tenant) { Run.start!(kind: "reindex") }
    Tenant.switch(tenant) { ReindexItemsJob.perform_now(tenant.id, index, run.id) }
    Tenant.switch(tenant) { run.reload }
  end

  def titles(tenant = @tenant, query = nil)
    SearchIndex.refresh!
    Tenant.switch(tenant) { Item.search(query).pluck(:title).sort }
  end

  test "a catalog the index lost is put back" do
    Tenant.switch(@tenant) do
      SearchIndex.client.delete_by_query(
        index: SearchIndex.alias_for(@tenant), body: { query: { match_all: {} } },
        refresh: true, conflicts: "proceed"
      )
    end

    assert_empty titles

    run = reindex

    assert_equal [ "Beach photo", "March invoice" ], titles
    assert_equal "done", run.status
    assert_equal 2, run.processed
  end

  test "a document whose body drifted is rewritten from the record" do
    Tenant.switch(@tenant) do
      item = Item.find_by!(title: "March invoice")
      Item.where(id: item.id).update_all(title: "April invoice")
    end

    assert_equal [], titles(@tenant, "April")

    reindex

    assert_equal [ "April invoice" ], titles(@tenant, "April")
  end

  test "reindexing one tenant leaves another's documents alone" do
    reindex(@tenant)

    assert_equal [ "Acme invoice" ], titles(@other)
  end

  test "a closed gate stops it before it writes anything" do
    Tenant.switch(@tenant) do
      Gate.set!(key: "reindex", enabled: false)
      SearchIndex.client.delete_by_query(
        index: SearchIndex.alias_for(@tenant), body: { query: { match_all: {} } },
        refresh: true, conflicts: "proceed"
      )
    end

    run = reindex

    assert_equal "gated", run.status
    assert_empty titles
  end

  test "a dry run counts what it would write, and writes none of it" do
    Tenant.switch(@tenant) do
      Gate.set!(key: "reindex", enabled: true, live: false)
      SearchIndex.client.delete_by_query(
        index: SearchIndex.alias_for(@tenant), body: { query: { match_all: {} } },
        refresh: true, conflicts: "proceed"
      )
    end

    run = reindex

    assert_equal "done", run.status
    assert_equal 2, run.processed
    assert_empty titles
  end

  test "it walks in pages, so a catalog larger than one page is covered whole" do
    Tenant.switch(@tenant) do
      (ReindexItemsJob::PAGE + 5).times do |n|
        create_item(kind: "pdf", title: "bulk-#{n}", locator_key: "bulk/#{n}.pdf")
      end

      SearchIndex.client.delete_by_query(
        index: SearchIndex.alias_for(@tenant), body: { query: { match_all: {} } },
        refresh: true, conflicts: "proceed"
      )
    end

    run = reindex

    assert_equal ReindexItemsJob::PAGE + 7, run.processed
  end

  test "a reindex into another index leaves the one being queried alone" do
    target = SearchIndex.build!

    Tenant.switch(@tenant) do
      SearchIndex.client.delete_by_query(
        index: SearchIndex.alias_for(@tenant), body: { query: { match_all: {} } },
        refresh: true, conflicts: "proceed"
      )
    end

    reindex(@tenant, index: target)

    assert_empty titles, "the live index answered from the index being built"

    SearchIndex.refresh!(index: target)

    assert_equal 2, SearchIndex.client.count(index: target)["count"]
  ensure
    SearchIndex.client.indices.delete(index: target, ignore: 404) if target
  end

  test "promoting swaps every alias at once, and the tenant filter comes with them" do
    target = SearchIndex.build!

    reindex(@tenant, index: target)
    reindex(@other, index: target)

    retired = SearchIndex.live_index

    SearchIndex.promote!(target, at_least: 3)

    assert_equal target, SearchIndex.live_index
    assert_equal [ "Beach photo", "March invoice" ], titles(@tenant)
    assert_equal [ "Acme invoice" ], titles(@other)
    assert_not SearchIndex.client.indices.exists(index: retired), "the retired index was left behind"
  end

  test "an index holding less than it should is not promoted" do
    target = SearchIndex.build!

    reindex(@tenant, index: target)

    error = assert_raises(ArgumentError) { SearchIndex.promote!(target, at_least: 3) }

    assert_match(/fewer than the 3 expected/, error.message)
    assert_not_equal target, SearchIndex.live_index
    assert_equal [ "Acme invoice" ], titles(@other)
  ensure
    SearchIndex.client.indices.delete(index: target, ignore: 404) if target
  end

  test "a tenant created after the swap gets its alias on the index now live" do
    target = SearchIndex.build!

    reindex(@tenant, index: target)
    reindex(@other, index: target)
    SearchIndex.promote!(target, at_least: 3)

    late = Tenant.create!(subdomain: "late-#{SecureRandom.hex(4)}", name: "Late")

    Tenant.switch(late) { create_item(kind: "pdf", title: "Late invoice") }

    assert_equal [ "Late invoice" ], titles(late)
  end

  test "a reindex spends one request per page, not one per item" do
    Tenant.switch(@tenant) do
      Array.new(5) { |n| create_item(kind: "pdf", title: "paged-#{n}") }
    end

    bulks = 0
    singles = 0

    SearchIndex.client.define_singleton_method(:bulk) { |**| bulks += 1; { "items" => [] } }
    SearchIndex.client.define_singleton_method(:index) { |**| singles += 1; {} }

    begin
      Tenant.switch(@tenant) { ReindexItemsJob.perform_now(@tenant.id) }
    ensure
      SearchIndex.client.singleton_class.remove_method(:bulk)
      SearchIndex.client.singleton_class.remove_method(:index)
    end

    assert_equal 0, singles, "a rebuild must not put one document per request"
    assert_equal 1, bulks, "a page under the page size is one request"
  end
end
