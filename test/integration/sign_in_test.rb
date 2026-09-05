require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(subdomain: "signin-#{SecureRandom.hex(4)}", name: "Sign in")
    connect!(@tenant)

    Tenant.switch(@tenant) { @item = create_item(kind: "pdf", title: "An invoice") }
  end

  test "starting a sign-in redirects to this tenant's issuer with pkce" do
    get "/auth", headers: host

    assert_response :redirect

    query = Rack::Utils.parse_query(URI.parse(response.location).query)

    assert response.location.start_with?(issuer.url_for(@tenant.subdomain))
    assert_equal "code", query["response_type"]
    assert_equal "S256", query["code_challenge_method"]
    assert query["state"].present?
    assert query["nonce"].present?
    assert_includes query["scope"].split, "uris:catalog:read"
    assert_equal "http://#{@tenant.subdomain}.uris.test/mcp", query["resource"]
    assert_not_includes response.location, "code_verifier"
  end

  test "the callback exchanges the code and establishes a session" do
    sign_in

    assert_response :redirect
    assert_equal "http://#{@tenant.subdomain}.uris.test/", response.location
  end

  test "the session endpoint answers who is signed in" do
    sign_in

    get "/auth/session", headers: host

    assert_response :success

    account = response.parsed_body

    assert_equal true, account["signed_in"]
    assert_equal "owner", account["nickname"]
    assert_equal "owner@example.invalid", account["email"]
    assert_equal @tenant.subdomain, account.dig("tenant", "subdomain")
    assert_includes account["scopes"], "uris:catalog:read"
    assert_nil account["access_token"], "a token must never reach the browser"
  end

  test "the session endpoint refuses a browser that has not signed in" do
    get "/auth/session", headers: host

    assert_response :unauthorized
    assert_equal false, response.parsed_body["signed_in"]
    assert_equal "/auth/", response.parsed_body["login_url"]
  end

  test "a signed-in browser queries graphql on the cookie alone" do
    sign_in

    post "/graphql", params: { query: "{ items { nodes { title } } }" }, headers: host

    assert_response :success
    assert_equal [ { "title" => "An invoice" } ],
                 response.parsed_body.dig("data", "items", "nodes")
  end

  test "the session fits in a cookie, because three JWTs do not" do
    sign_in

    held = cookies["_uris_session"].to_s

    assert held.present?
    assert_operator held.bytesize, :<, 4096,
                    "the id token must not be kept once its claims are read"

    get "/auth/session", headers: host

    assert_equal "owner", response.parsed_body["nickname"],
                 "dropping the id token must not drop who is signed in"
  end

  test "a callback whose state does not match this browser is refused" do
    get "/auth", headers: host
    granted = issuer.authorize!(response.location)

    get "/auth/callback", params: { code: granted[:code], state: "forged" }, headers: host

    assert_response :bad_request
    assert_no_session
  end

  test "a callback with no authorization in flight is refused" do
    get "/auth/callback", params: { code: "abc", state: "whatever" }, headers: host

    assert_response :bad_request
    assert_no_session
  end

  test "the issuer refusing the code leaves no session behind" do
    get "/auth", headers: host
    granted = issuer.authorize!(response.location)

    get "/auth/callback", params: { code: "never-issued", state: granted[:state] }, headers: host

    assert_response :bad_request
    assert_no_session
  end

  test "a code redeemed twice fails the second time" do
    get "/auth", headers: host
    granted = issuer.authorize!(response.location)

    get "/auth/callback", params: { code: granted[:code], state: granted[:state] }, headers: host
    assert_response :redirect

    get "/auth", headers: host
    second = issuer.authorize!(response.location)

    get "/auth/callback", params: { code: granted[:code], state: second[:state] }, headers: host

    assert_response :bad_request
  end

  test "signing out drops the session" do
    sign_in

    delete "/auth/logout", headers: host

    assert_no_session
  end

  test "the scopes the session carries are the ones the issuer granted" do
    sign_in(scopes: %w[uris:catalog:read])

    get "/auth/session", headers: host

    assert_equal [ "uris:catalog:read" ], response.parsed_body["scopes"] & Grant::SCOPES

    post "/graphql",
         params: { query: "mutation($id: ID!) { analyzeItem(input: { id: $id }) { run { id } } }",
                   variables: { id: @item.id.to_s } },
         headers: host

    assert_match(/does not carry uris:catalog:write/,
                 response.parsed_body.dig("errors", 0, "message"))
  end

  private

    def host
      { "HOST" => "#{@tenant.subdomain}.uris.test" }
    end

    def sign_in(scopes: Grant::SCOPES)
      get "/auth", headers: host
      granted = issuer.authorize!(response.location, scopes: scopes)

      get "/auth/callback",
          params: { code: granted[:code], state: granted[:state] }, headers: host
    end

    def assert_no_session
      get "/auth/session", headers: host

      assert_response :unauthorized
    end
end
