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

    # Add more helper methods to be used by all tests here...
  end
end
