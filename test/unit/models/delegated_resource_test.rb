require "test_helper"
require "masks/client/delegations/fake"

class DelegatedResourceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  DRIVE = "https://www.googleapis.com/drive/v3".freeze

  setup do
    @masks = Delegations.fake = Masks::Client::Delegations::Fake.new
    @tenant = Tenant.create!(subdomain: "delegated-#{SecureRandom.hex(4)}", name: "Delegated")

    started = @masks.start(provider: "google")
    @held = @masks.finish(params: @masks.approve(started, subject: "ada", connection: "c-1"), started: started)

    Tenant.switch(@tenant) do
      @resource = Resource::OauthGoogle.create!(key: "drive", name: "Drive")
      @resource.connect!(@held, by: "ada")
    end
  end

  teardown do
    Delegations.fake = nil
  end

  def within(&block)
    Tenant.switch(@tenant, &block)
  end

  test "a connected resource holds the delegation, never an upstream token it was not handed" do
    within do
      assert @resource.connected?
      refute @resource.needs_connect?
      assert_equal "ada", @resource.connected_by
      assert_equal "c-1", @resource.reload.delegation["connection"]
      assert_nil @resource.credentials["upstream"]
    end
  end

  test "a cached upstream token is used until it runs out, and then masks is asked again" do
    within do
      assert_equal "google-access-1", @resource.upstream_token
      assert_equal "google-access-1", Resource.find(@resource.id).upstream_token
    end

    assert_equal 1, @masks.releases

    travel 2.hours do
      within { assert_equal "google-access-2", Resource.find(@resource.id).upstream_token }
    end

    assert_equal 2, @masks.releases
  end

  test "every rotated secret is kept, so the next release still works" do
    within do
      @resource.upstream_token
      @resource.token_expired!

      assert_equal "google-access-2", Resource.find(@resource.id).upstream_token
      assert_equal "google-access-3", Resource.find(@resource.id).tap(&:token_expired!).upstream_token
    end
  end

  test "a refusal marks the resource as needing a connection and stops using it" do
    @masks.revoke("c-1")

    within do
      error = assert_raises(Resource::Unusable) { @resource.upstream_token }

      assert_match(/connect it again/, error.message)
      assert @resource.reload.needs_connect?
      assert @resource.needs_connect_at
    end
  end

  test "masks not answering is worth retrying, and asks nobody to connect again" do
    @masks.unavailable("c-1")

    within do
      assert_raises(Resource::Failed) { @resource.upstream_token }

      refute_kind_of Resource::Unusable, (begin
        @resource.upstream_token
      rescue Resource::Failed => e
        e
      end)
      refute @resource.reload.needs_connect?
    end
  end

  test "a resource nobody connected yet says so" do
    within do
      fresh = Resource::OauthGoogle.create!(key: "unconnected")

      assert fresh.needs_connect?
      assert_raises(Resource::Unusable) { fresh.upstream_token }
    end
  end

  test "a check that passes after connecting again clears the mark" do
    @masks.revoke("c-1")

    within do
      refute @resource.check
      assert @resource.reload.needs_connect?

      started = @masks.start(provider: "google")
      @resource.connect!(@masks.finish(params: @masks.approve(started, subject: "ada", connection: "c-2"), started: started), by: "ada")

      stub_request(:get, "#{DRIVE}/about?fields=user").to_return(status: 200, body: { user: { emailAddress: "ada@example.com" } }.to_json)

      assert @resource.check
      refute @resource.reload.needs_connect?
    end
  end

  test "a sync whose connection was withdrawn stops rather than retrying" do
    @masks.revoke("c-1")

    onedrive = within do
      Resource::MicrosoftGraph.create!(key: "onedrive").tap { |held| held.connect!(@held, by: "ada") }
    end

    within do
      assert_nothing_raised { SyncResourceJob.perform_now(@tenant.id, onedrive.id) }
    end

    assert_equal 0, enqueued_jobs.count { |job| job["job_class"] == "SyncResourceJob" }
    within { assert onedrive.reload.needs_connect? }
  end

  test "an upstream token is never kept in the clear" do
    within { @resource.upstream_token }

    raw = ActiveRecord::Base.connection.select_value("SELECT credentials FROM resources WHERE id = #{@resource.id.to_i}")

    refute_includes raw.to_s, "google-access-1"
    refute_includes raw.to_s, @held.secret
  end
end
