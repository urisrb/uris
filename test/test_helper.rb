ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require_relative "support/offline"
require_relative "support/fake_issuer"
require_relative "support/fake_search_engine"
require_relative "support/mcp_client"

ENV["URIS_PUBLIC_ORIGIN"] = nil

SEARCH_ENGINE_URL = ENV["OPENSEARCH_URL"].presence

unless SEARCH_ENGINE_URL
  SearchIndex.define_singleton_method(:client) { @client ||= FakeSearchEngine.new }
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    parallelize_setup { |worker| ENV["TEST_ENV_NUMBER"] = worker.to_s }

    setup do
      Masks::Client.registry.clear!
      ENV["MASKS_ISSUER_TEMPLATE"] = FakeIssuer.template
    end

    def requires_search_engine!
      return if SEARCH_ENGINE_URL

      skip "asserts what the search engine does; set OPENSEARCH_URL to run it"
    end

    def issuer
      FakeIssuer.current
    end

    def connect!(tenant, client_id: "items-test-client", client_secret: "items-test-secret")
      tenant.update!(
        client_id: client_id,
        client_secret: client_secret,
        registration_access_token: "items-test-registration-token",
        registration_client_uri: "#{issuer.url_for(tenant.subdomain)}/register/#{client_id}",
        connected_at: Time.current
      )
    end

    fixtures :all

    def create_item(kind:, title: nil, resource: nil, locator_key: nil, locator: {})
      item = Item.create!(kind: kind, title: title)
      item.references.create!(resource: resource || scratch_resource,
                               locator_key: locator_key, locator: locator)
      item.references.reset
      item
    end

    def scratch_resource
      @scratch_resources ||= {}
      @scratch_resources[Current.tenant.id] ||= Resource::S3.create!(
        key: "scratch-#{SecureRandom.hex(4)}",
        details: { "endpoint" => "http://127.0.0.1:1" },
        credentials: { "access_key_id" => "k", "secret_access_key" => "s" }
      )
    end

    def item_at(locator_key)
      Item.joins(:references).find_by!(item_references: { locator_key: locator_key })
    end
  end
end
