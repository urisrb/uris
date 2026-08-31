require "test_helper"

class SearchIndexTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @jons = Tenant.create!(subdomain: "jons-#{SecureRandom.hex(4)}", name: "Jon's things")
    @acme = Tenant.create!(subdomain: "acme-#{SecureRandom.hex(4)}", name: "Acme")

    Tenant.switch(@jons) do
      create_thing(kind: "pdf", title: "March invoice", locator_key: "invoices/march.pdf")
      create_thing(kind: "image", title: "Beach photo", locator_key: "photos/beach.jpg")
      create_thing(kind: "pdf", title: "file-1.pdf", locator_key: "docs/file-1.pdf")
      create_thing(kind: "pdf", title: "file-2.pdf", locator_key: "docs/file-2.pdf")
    end

    Tenant.switch(@acme) do
      create_thing(kind: "pdf", title: "Acme invoice", locator_key: "invoices/acme.pdf")
    end

    SearchIndex.refresh!
  end

  test "search finds things by title" do
    Tenant.switch(@jons) do
      assert_equal [ "March invoice" ], Thing.search("March").pluck(:title)
    end
  end

  test "search finds things by locator" do
    Tenant.switch(@jons) do
      assert_equal [ "Beach photo" ], Thing.search("beach").pluck(:title)
    end
  end

  test "a search never crosses tenants, even for a shared term" do
    Tenant.switch(@jons) do
      assert_equal [ "March invoice" ], Thing.search("invoice").pluck(:title)
    end

    Tenant.switch(@acme) do
      assert_equal [ "Acme invoice" ], Thing.search("invoice").pluck(:title)
    end
  end

  test "the tenant filter is on the alias, so the engine applies it" do
    hits = SearchIndex.client.search(
      index: SearchIndex.alias_for(@jons),
      body: { query: { match_all: {} } }
    ).dig("hits", "hits")

    assert_equal [ @jons.id ], hits.map { |h| h.dig("_source", "tenant_id") }.uniq
  end

  test "digits in a path are searchable and distinguish siblings" do
    Tenant.switch(@jons) do
      assert_equal [ "file-1.pdf" ], Thing.search("file-1").pluck(:title)
    end
  end

  test "kind narrows results" do
    Tenant.switch(@jons) do
      assert_equal [ "Beach photo" ], Thing.search(nil, kind: "image").pluck(:title)
    end
  end

  test "searching with no tenant in scope raises rather than returning everything" do
    assert_raises(ArgumentError) { SearchIndex.search("invoice", tenant: nil) }
  end

  test "a destroyed thing leaves the index" do
    Tenant.switch(@jons) do
      Thing.find_by!(title: "March invoice").destroy!
      SearchIndex.refresh!

      assert_equal [], Thing.search("March").pluck(:title)
    end
  end

  test "a page is indexed in one request rather than one per document" do
    things = Tenant.switch(@jons) do
      Array.new(3) { |n| Thing.create!(kind: "pdf", title: "bulk #{n}") }
    end

    calls = []

    SearchIndex.client.define_singleton_method(:bulk) { |**args| calls << args; { "items" => [] } }

    begin
      assert_equal 3, SearchIndex.index_all(things)
    ensure
      SearchIndex.client.singleton_class.remove_method(:bulk)
    end

    assert_equal 1, calls.length, "three documents must not cost three requests"
    assert_equal 6, calls.first[:body].length, "an action line and a document for each"
  end

  test "documents written in bulk are the ones that come back" do
    things = Tenant.switch(@jons) do
      Array.new(3) { |n| Thing.create!(kind: "data", title: "bulked-#{n}") }
    end

    assert_equal 3, SearchIndex.index_all(things)

    SearchIndex.refresh!

    Tenant.switch(@jons) do
      assert_equal things.map(&:id).sort, SearchIndex.search("bulked", kind: "data").sort
    end
  end

  test "a bulk write the engine refused raises rather than reporting success" do
    thing = Tenant.switch(@jons) { Thing.create!(kind: "pdf", title: "refused") }
    refusal = { "items" => [ { "index" => { "error" => { "reason" => "mapper_parsing_exception" } } } ] }

    SearchIndex.client.define_singleton_method(:bulk) { |**| refusal }

    begin
      error = assert_raises(SearchIndex::Failed) { SearchIndex.index_all([ thing ]) }

      assert_match(/mapper_parsing_exception/, error.message)
    ensure
      SearchIndex.client.singleton_class.remove_method(:bulk)
    end
  end

  test "indexing nothing asks the engine nothing" do
    SearchIndex.client.define_singleton_method(:bulk) { |**| raise "bulk should not be called" }

    begin
      assert_equal 0, SearchIndex.index_all([])
    ensure
      SearchIndex.client.singleton_class.remove_method(:bulk)
    end
  end
end
