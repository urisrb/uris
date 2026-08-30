require "test_helper"

class ThingChangedTest < ActionCable::Channel::TestCase
  tests GraphqlChannel

  EVERY_THING = <<~GRAPHQL
    subscription ThingChanged { thingChanged { thing { id kind title } } }
  GRAPHQL

  ONE_THING = <<~GRAPHQL
    subscription ThingChanged($id: ID!) { thingChanged(id: $id) { thing { id title } } }
  GRAPHQL

  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "sub-#{SecureRandom.hex(4)}", name: "Subscribed")
    @other = Tenant.create!(subdomain: "sub-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(@tenant) do
      @storage = Resource::Database.create!(key: "database", name: "Storage")
      @thing = thing_on("notes.txt", "the notes")
      @unwatched = thing_on("other.txt", "other notes")
    end
  end

  test "subscribing listens on an event stream of its own" do
    subscribe_as(@tenant, EVERY_THING)

    assert_not_nil event_stream
  end

  test "finishing an analysis reaches a tenant-wide subscriber's stream" do
    subscribe_as(@tenant, EVERY_THING)
    stream = event_stream

    assert_broadcasts(stream, 1) { analyze(@thing) }
    assert_includes broadcasts(stream).last, @thing.to_gid_param
  end

  test "a second analysis is a second event" do
    subscribe_as(@tenant, EVERY_THING)
    stream = event_stream

    assert_broadcasts(stream, 2) do
      analyze(@thing)
      analyze(@unwatched)
    end
  end

  test "watching one thing hears that thing and not the others" do
    subscribe_as(@tenant, ONE_THING, id: @thing.to_gid_param)
    stream = event_stream

    assert_no_broadcasts(stream) { analyze(@unwatched) }
    assert_broadcasts(stream, 1) { analyze(@thing) }
  end

  test "another tenant's subscriber is on a different stream entirely" do
    subscribe_as(@tenant, EVERY_THING)
    mine = event_stream

    subscribe_as(@other, EVERY_THING)
    theirs = event_stream

    assert_not_equal mine, theirs
    assert_no_broadcasts(theirs) { analyze(@thing) }
  end

  private

    def analyze(thing)
      Tenant.switch(@tenant) { Analyzer.for(thing).run }
    end

    def thing_on(key, body)
      @storage.upload(key, body)

      ThingReference.discover!(resource: @storage, locator: { "key" => key },
                               locator_key: key, kind: "text", title: key).thing
    end

    def subscribe_as(tenant, query, **variables)
      stub_connection(tenant: tenant)
      subscribe
      perform :execute, "query" => query, "variables" => variables.stringify_keys
    end

    def event_stream
      subscription.streams.find { |stream| stream.start_with?("graphql-event:") }
    end
end
