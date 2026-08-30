ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

ENV["MASKS_ISSUER_TEMPLATE"] = "http://%{subdomain}.auth.test:5555"
ENV["MASKS_DEV_SECRET"] = "test_only_secret_masks_will_replace"
ENV["THINGS_PUBLIC_ORIGIN"] = nil

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Rails gives each worker its own databases but knows nothing about the
    # search index, and the suite resets that index in setup. Without a name
    # per worker they delete each other's.
    parallelize_setup { |worker| ENV["TEST_ENV_NUMBER"] = worker.to_s }

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A thing is a group of references, so building one for a test means building
    # at least one place it lives. Assumes a tenant is already switched in.
    def create_thing(kind:, title: nil, resource: nil, locator_key: nil, locator: {})
      thing = Thing.create!(kind: kind, title: title)
      thing.references.create!(resource: resource || scratch_resource,
                               locator_key: locator_key, locator: locator)
      thing.references.reset
      thing
    end

    def scratch_resource
      @scratch_resources ||= {}
      @scratch_resources[Current.tenant.id] ||= Resource::S3.create!(
        key: "scratch-#{SecureRandom.hex(4)}",
        details: { "endpoint" => "http://127.0.0.1:1" },
        credentials: { "access_key_id" => "k", "secret_access_key" => "s" }
      )
    end

    def thing_at(locator_key)
      Thing.joins(:references).find_by!(thing_references: { locator_key: locator_key })
    end

    # Add more helper methods to be used by all tests here...
  end
end
