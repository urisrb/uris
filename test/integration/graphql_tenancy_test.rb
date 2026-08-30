require "test_helper"

class GraphqlTenancyTest < ActionDispatch::IntegrationTest
  CATALOG = "{ tenant { name subdomain } things { kind title } }".freeze

  setup do
    @jons = Tenant.create!(subdomain: "jons", name: "Jon's things")
    @acme = Tenant.create!(subdomain: "acme", name: "Acme")

    Tenant.switch(@jons) { Thing.create!(kind: "pdf", title: "Jon's invoice") }
    Tenant.switch(@acme) { Thing.create!(kind: "pdf", title: "Acme's invoice") }
  end

  test "each tenant's catalog contains only its own things" do
    assert_equal(
      { "tenant" => { "name" => "Jon's things", "subdomain" => "jons" },
        "things" => [ { "kind" => "pdf", "title" => "Jon's invoice" } ] },
      query_as("jons")
    )

    assert_equal(
      { "tenant" => { "name" => "Acme", "subdomain" => "acme" },
        "things" => [ { "kind" => "pdf", "title" => "Acme's invoice" } ] },
      query_as("acme")
    )
  end

  test "an unknown subdomain resolves to no tenant at all" do
    host! "nobody.things.test"
    post "/graphql", params: { query: CATALOG }

    assert_response :not_found
  end

  private

    def query_as(subdomain)
      host! "#{subdomain}.things.test"
      post "/graphql", params: { query: CATALOG }

      assert_response :success
      JSON.parse(response.body).fetch("data")
    end
end
