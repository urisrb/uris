require "test_helper"
require_relative "../support/fake_broker_server"

class BrokeredResourceTest < ActiveSupport::TestCase
  RELEASE = "/connections/token".freeze

  setup do
    @broker = FakeBrokerServer.current
    @broker.reset!

    @tenant = Tenant.create!(subdomain: "broker-#{SecureRandom.hex(4)}", name: "Broker")

    Tenant.switch(@tenant) do
      @resource = Resource::OauthGoogle.create!(key: "drive", name: "Drive")
      @resource.connection_id = "11111111-2222-3333-4444-555555555555"
      @resource.save!
    end

    Current.issuer = @broker.url
    Current.credentials = "Bearer caller-token"
  end

  teardown do
    Current.issuer = nil
    Current.credentials = nil
  end

  def released(access_token: "google-access")
    @broker.on(RELEASE, body: { "access_token" => access_token, "connection" => { "provider" => "google" } })
  end

  test "the connection id is what the resource stores, and never a refresh token" do
    Tenant.switch(@tenant) do
      held = Resource::OauthGoogle.find_by(key: "drive")

      assert_equal "11111111-2222-3333-4444-555555555555", held.connection_id
      assert_equal [ "connection_id" ], held.credentials.keys
    end
  end

  test "an upstream token is fetched from the broker with the caller's own token" do
    released

    Tenant.switch(@tenant) { assert_equal "google-access", @resource.upstream_token }

    assert_equal [ "Bearer caller-token" ], @broker.authorizations_for(RELEASE)
    assert_equal [ "11111111-2222-3333-4444-555555555555" ],
                 @broker.bodies_for(RELEASE).map { |body| body["connection_id"] }
  end

  test "the upstream token is fetched once per resource, not once per call" do
    released

    Tenant.switch(@tenant) do
      3.times { @resource.upstream_token }
    end

    assert_equal 1, @broker.count_for(RELEASE),
                 "the broker must be on the refresh path, not on every request"
  end

  test "a request with no caller token cannot reach the broker at all" do
    released
    Current.credentials = nil

    error = assert_raises(Broker::Unauthorized) do
      Tenant.switch(@tenant) { @resource.upstream_token }
    end

    assert_match(/carries no token/, error.message)
    assert_equal 0, @broker.count_for(RELEASE)
  end

  test "a refused release surfaces the broker's reason" do
    @broker.on(RELEASE, status: 403,
                        body: { "error" => "insufficient_scope",
                                "error_description" => "this token does not carry masks:connections:google" })

    error = assert_raises(Broker::Unauthorized) do
      Tenant.switch(@tenant) { @resource.upstream_token }
    end

    assert_match(/masks:connections:google/, error.message)
  end

  test "a revoked connection is reported rather than retried forever" do
    @broker.on(RELEASE, status: 400,
                        body: { "error" => "invalid_grant", "error_description" => "that connection has been revoked" })

    error = assert_raises(Broker::Error) do
      Tenant.switch(@tenant) { @resource.upstream_token }
    end

    assert_match(/revoked/, error.message)
  end

  test "a broker that cannot be reached fails as a resource failure" do
    Current.issuer = "http://127.0.0.1:1"

    assert_raises(Broker::Unreachable) do
      Tenant.switch(@tenant) { @resource.upstream_token }
    end
  end

  test "a brokered resource cannot be given a sync schedule it cannot honour" do
    Tenant.switch(@tenant) do
      held = Resource::OauthGoogle.find_by(key: "drive")
      held.sync_interval = 5.minutes

      assert_not held.valid?
      assert_match(/cannot sync/, held.errors.full_messages.to_sentence)
    end
  end

  test "a resource with no connection says so rather than calling the broker" do
    Tenant.switch(@tenant) do
      bare = Resource::OauthGoogle.create!(key: "bare", name: "Bare")

      error = assert_raises(Resource::Failed) { bare.upstream_token }

      assert_match(/names no connection/, error.message)
    end

    assert_equal 0, @broker.count_for(RELEASE)
  end
end
