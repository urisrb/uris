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
end
