require "test_helper"

class GraphqlTenancyTest < ActionDispatch::IntegrationTest
  CATALOG = "{ tenant { name subdomain } items { nodes { kind title } } }".freeze

  setup do
    @demo = Tenant.create!(subdomain: "demo", name: "Demo items")
    @acme = Tenant.create!(subdomain: "acme", name: "Acme")

    Tenant.switch(@demo) { @demo_item = Feed.create!(type: Feed::FILE, key: "Demo invoice", title: "Demo invoice") }
    Tenant.switch(@acme) { @acme_item = Feed.create!(type: Feed::FILE, key: "Acme's invoice", title: "Acme's invoice") }
  end

  test "each tenant's catalog contains only its own items" do
    assert_equal(
      { "tenant" => { "name" => "Demo items", "subdomain" => "demo" },
        "items" => { "nodes" => [ { "kind" => "pdf", "title" => "Demo invoice" } ] } },
      query_as("demo")
    )

    assert_equal(
      { "tenant" => { "name" => "Acme", "subdomain" => "acme" },
        "items" => { "nodes" => [ { "kind" => "pdf", "title" => "Acme's invoice" } ] } },
      query_as("acme")
    )
  end

  test "fetching an item by id is bounded by the tenant that asked" do
    assert_equal(
      { "feed" => nil },
      query_as("demo", "{ item(id: #{@acme_item.id}) { title } }")
    )

    assert_equal(
      { "feed" => { "title" => "Demo invoice" } },
      query_as("demo", "{ item(id: #{@demo_item.id}) { title } }")
    )
  end

  test "an unknown subdomain resolves to no tenant at all" do
    host! "nobody.uris.test"
    post "/graphql", params: { query: CATALOG }

    assert_response :not_found
  end

  private

    def query_as(subdomain, query = CATALOG)
      host! "#{subdomain}.uris.test"
      post "/graphql", params: { query: query }, headers: bearer(subdomain)

      assert_response :success
      JSON.parse(response.body).fetch("data")
    end

    def bearer(subdomain, scopes: Grant::SCOPES)
      token = issuer.mint(
        subdomain: subdomain, scopes: scopes,
        audience: "http://#{subdomain}.uris.test/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end
end
