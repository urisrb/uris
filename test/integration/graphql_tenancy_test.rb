require "test_helper"

class GraphqlTenancyTest < ActionDispatch::IntegrationTest
  CATALOG = "{ tenant { name subdomain } things { nodes { kind title } } }".freeze

  setup do
    @demo = Tenant.create!(subdomain: "demo", name: "Demo things")
    @acme = Tenant.create!(subdomain: "acme", name: "Acme")

    Tenant.switch(@demo) { @demo_thing = Thing.create!(kind: "pdf", title: "Demo invoice") }
    Tenant.switch(@acme) { @acme_thing = Thing.create!(kind: "pdf", title: "Acme's invoice") }
  end

  test "each tenant's catalog contains only its own things" do
    assert_equal(
      { "tenant" => { "name" => "Demo things", "subdomain" => "demo" },
        "things" => { "nodes" => [ { "kind" => "pdf", "title" => "Demo invoice" } ] } },
      query_as("demo")
    )

    assert_equal(
      { "tenant" => { "name" => "Acme", "subdomain" => "acme" },
        "things" => { "nodes" => [ { "kind" => "pdf", "title" => "Acme's invoice" } ] } },
      query_as("acme")
    )
  end

  test "fetching a thing by id is bounded by the tenant that asked" do
    assert_equal(
      { "thing" => nil },
      query_as("demo", "{ thing(id: #{@acme_thing.id}) { title } }")
    )

    assert_equal(
      { "thing" => { "title" => "Demo invoice" } },
      query_as("demo", "{ thing(id: #{@demo_thing.id}) { title } }")
    )
  end

  test "an unknown subdomain resolves to no tenant at all" do
    host! "nobody.things.test"
    post "/graphql", params: { query: CATALOG }

    assert_response :not_found
  end

  private

    def query_as(subdomain, query = CATALOG)
      host! "#{subdomain}.things.test"
      post "/graphql", params: { query: query }, headers: bearer(subdomain)

      assert_response :success
      JSON.parse(response.body).fetch("data")
    end

    def bearer(subdomain, scopes: Grant::SCOPES)
      token = issuer.mint(
        subdomain: subdomain, scopes: scopes,
        audience: "http://#{subdomain}.things.test/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end
end
