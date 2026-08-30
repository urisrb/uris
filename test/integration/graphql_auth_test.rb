require "test_helper"

class GraphqlAuthTest < ActionDispatch::IntegrationTest
  CATALOG = "{ things { nodes { kind title } } }".freeze
  RESOURCES = "{ resources { key } }".freeze
  ANALYZE = "mutation($id: ID!) { analyzeThing(input: { id: $id }) { run { id } } }".freeze

  setup do
    @tenant = Tenant.create!(subdomain: "auth-#{SecureRandom.hex(4)}", name: "Auth")
    @other = Tenant.create!(subdomain: "auth-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(@tenant) { @thing = create_thing(kind: "pdf", title: "An invoice") }
  end

  test "a query with no credentials is refused with somewhere to sign in" do
    post "/graphql", params: { query: CATALOG }, headers: host_for(@tenant)

    assert_response :unauthorized

    body = response.parsed_body

    assert_equal false, body["signed_in"]
    assert_equal "login_required", body["error"]
    assert_equal "/auth/", body["login_url"]
    assert_nil response.headers["WWW-Authenticate"],
               "a browser gets a login url; only a caller that presented a token gets a challenge"
  end

  test "a presented token that is bad gets the bearer challenge, not a login page" do
    post "/graphql", params: { query: CATALOG },
                     headers: host_for(@tenant).merge("Authorization" => "Bearer nonsense")

    assert_response :unauthorized
    assert_match(/\ABearer /, response.headers["WWW-Authenticate"])
    assert_includes response.headers["WWW-Authenticate"], "resource_metadata="
  end

  test "a token minted for another tenant cannot read this one" do
    post "/graphql", params: { query: CATALOG },
                     headers: host_for(@tenant).merge(bearer(@other))

    assert_response :unauthorized
  end

  test "a granted token reads the catalog" do
    post "/graphql", params: { query: CATALOG },
                     headers: host_for(@tenant).merge(bearer(@tenant))

    assert_response :success
    assert_equal [ { "kind" => "pdf", "title" => "An invoice" } ],
                 response.parsed_body.dig("data", "things", "nodes")
  end

  test "a read scope does not carry the resource list" do
    body = execute(RESOURCES, scopes: %w[things:read])

    assert_nil body.dig("data", "resources")
    assert_match(/does not carry resources:read/, body.dig("errors", 0, "message"))
  end

  test "a read scope cannot drive a mutation" do
    body = execute(ANALYZE, scopes: %w[things:read], variables: { id: @thing.id.to_s })

    assert_match(/does not carry things:write/, body.dig("errors", 0, "message"))
  end

  test "a write scope can" do
    body = execute(ANALYZE, scopes: %w[things:read things:write],
                            variables: { id: @thing.id.to_s })

    assert_nil body["errors"]
    assert body.dig("data", "analyzeThing", "run", "id").present?
  end

  test "resource commands want the resource scope, not the write scope" do
    body = execute(RESOURCES, scopes: %w[things:write resources:read])

    assert_nil body["errors"]
  end

  test "a read scope cannot walk from a thing to a resource" do
    query = "{ things { nodes { references { resource { key } } } } }"

    body = execute(query, scopes: %w[things:read])

    assert_nil body.dig("data", "things"),
               "nesting must not reach past the scope the entry point checked"
    assert body["errors"].present?
  end

  test "holding both scopes walks the whole way" do
    query = "{ things { nodes { references { resource { key } } } } }"

    body = execute(query, scopes: %w[things:read resources:read])

    assert_nil body["errors"]
    assert body.dig("data", "things", "nodes", 0, "references", 0, "resource", "key").present?
  end

  test "streaming a reference out needs a grant too" do
    reference = @thing.references.first

    get "/references/#{reference.id}/thumbnail", headers: host_for(@tenant)

    assert_response :unauthorized
  end

  private

    def host_for(tenant)
      { "HOST" => "#{tenant.subdomain}.things.test" }
    end

    def bearer(tenant, scopes: Grant::SCOPES)
      token = issuer.mint(
        subdomain: tenant.subdomain, scopes: scopes,
        audience: "http://#{tenant.subdomain}.things.test/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end

    def execute(query, scopes:, variables: nil)
      post "/graphql",
           params: { query: query, variables: variables }.compact,
           headers: host_for(@tenant).merge(bearer(@tenant, scopes: scopes))

      response.parsed_body
    end
end
