require "test_helper"

class PairingTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(subdomain: "pairing-#{SecureRandom.hex(4)}", name: "Pairing")
  end

  test "an unpaired tenant is offered setup rather than an app that cannot sign anyone in" do
    get "/", headers: host

    assert_redirected_to setup_path

    get "/setup", headers: host

    assert_response :success
    assert_match "has not been set up", response.body
    assert_no_match issuer.origin, response.body
  end

  test "starting setup sends the browser to its issuer, naming one origin throughout" do
    post "/setup", headers: host

    assert_response :redirect

    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    origin = "http://#{@tenant.subdomain}.things.test"

    assert response.location.start_with?("#{issuer.url_for(@tenant.subdomain)}/setup/connect")
    assert_equal "#{origin}/mcp", query["resource"]
    assert_equal "#{origin}/setup/callback", query["return_to"]
    assert_equal "#{origin}/auth/callback", query["redirect_uris"]
    assert_includes query["scope"].split, "things:read"
    assert query["state"].present?
  end

  test "the callback redeems the token and stores credentials nobody typed in" do
    post "/setup", headers: host
    state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

    get "/setup/callback",
        params: { initial_access_token: issuer.approve!(@tenant.subdomain), state: state },
        headers: host

    assert_redirected_to "/auth/"

    @tenant.reload

    assert @tenant.paired?
    assert @tenant.client_secret.present?
    assert @tenant.registration_access_token.present?
    assert @tenant.paired_at.present?
  end

  test "the credentials are encrypted at rest" do
    pair!(@tenant)

    stored = Tenant.connection.select_one(
      "SELECT client_secret, registration_access_token FROM tenants WHERE id = #{@tenant.id}"
    )

    assert_not_equal "things-test-secret", stored["client_secret"]
    assert_no_match(/things-test-secret/, stored.values.join)
  end

  test "a callback whose state does not match this browser redeems nothing" do
    post "/setup", headers: host

    get "/setup/callback",
        params: { initial_access_token: issuer.approve!(@tenant.subdomain), state: "forged" },
        headers: host

    assert_response :bad_request
    assert_not @tenant.reload.paired?
  end

  test "a callback with no pairing in flight is refused" do
    get "/setup/callback",
        params: { initial_access_token: "whatever", state: "whatever" }, headers: host

    assert_response :bad_request
    assert_not @tenant.reload.paired?
  end

  test "a token the issuer will not honour leaves the tenant unpaired" do
    post "/setup", headers: host
    state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

    get "/setup/callback",
        params: { initial_access_token: "never-approved", state: state }, headers: host

    assert_response :bad_request
    assert_match "invalid_token", response.body
    assert_not @tenant.reload.paired?
  end

  test "a token approved for another tenant does not pair this one" do
    other = Tenant.create!(subdomain: "other-#{SecureRandom.hex(4)}", name: "Other")

    post "/setup", headers: host
    state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

    get "/setup/callback",
        params: { initial_access_token: issuer.approve!(other.subdomain), state: state },
        headers: host

    assert_response :bad_request
    assert_not @tenant.reload.paired?
  end

  test "a paired tenant does not offer setup to a browser that is not signed in" do
    pair!(@tenant)

    get "/setup", headers: host

    assert_redirected_to root_path

    post "/setup", headers: host

    assert_redirected_to root_path
  end

  test "the client credentials the sign-in flow uses come from the row" do
    post "/setup", headers: host
    state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

    get "/setup/callback",
        params: { initial_access_token: issuer.approve!(@tenant.subdomain), state: state },
        headers: host

    get "/auth", headers: host

    query = Rack::Utils.parse_query(URI.parse(response.location).query)

    assert_equal @tenant.reload.client_id, query["client_id"]
  end

  private

    def host
      { "HOST" => "#{@tenant.subdomain}.things.test" }
    end
end
