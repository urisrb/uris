require "test_helper"

class FeedTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "feed-#{SecureRandom.hex(4)}", name: "Feeds")
  end

  test "a slug the application already answers to is refused" do
    Tenant.switch(@tenant) do
      Feed::RESERVED.first(4).each do |taken|
        feed = Feed.new(slug: taken, prompt: "find things")

        assert_not feed.valid?, "#{taken} should be refused"
        assert_match(/path uris already answers to/, feed.errors[:slug].first)
      end
    end
  end

  test "a slug is letters, numbers and dashes" do
    Tenant.switch(@tenant) do
      assert Feed.new(slug: "buy-2024", prompt: "x").valid?

      [ "Buy", "buy things", "buy/now", "-buy", "" ].each do |bad|
        assert_not Feed.new(slug: bad, prompt: "x").valid?, "#{bad.inspect} should be refused"
      end
    end
  end

  test "a slug is unique per tenant and free in another" do
    other = Tenant.create!(subdomain: "feed-#{SecureRandom.hex(4)}", name: "Other")

    Tenant.switch(@tenant) { Feed.create!(slug: "buy", prompt: "x") }
    Tenant.switch(@tenant) { assert_not Feed.new(slug: "buy", prompt: "x").valid? }
    Tenant.switch(other) { assert Feed.new(slug: "buy", prompt: "x").valid? }
  end

  test "run! opens a feed run pointing back at the feed" do
    Tenant.switch(@tenant) do
      feed = Feed.create!(slug: "buy", prompt: "x")
      run = feed.run!

      assert_equal "feed", run.kind
      assert_equal feed, run.feed
      assert run.open?
    end
  end

  test "a feed acts as itself rather than borrowing anyone's token" do
    Tenant.switch(@tenant) do
      feed = Feed.create!(slug: "buy", prompt: "x")

      assert_equal "feed:buy", feed.grant.subject
      assert_equal @tenant, feed.grant.tenant
    end
  end

  test "turns fall back to the default" do
    Tenant.switch(@tenant) do
      assert_equal Feed::TURNS, Feed.new(slug: "buy", prompt: "x").turns_allowed
      assert_equal 2, Feed.new(slug: "buy", prompt: "x", turns: 2).turns_allowed
    end
  end

  test "every path the application answers to is reserved" do
    spoken = Rails.application.routes.routes.filter_map do |route|
      route.path.spec.to_s[%r{\A/([a-z0-9-]+)}, 1]
    end.uniq

    assert_empty spoken - Feed::RESERVED,
                 "these are routes a feed slug could shadow"
  end

  test "kept_by is the items a feed holds and nothing else" do
    Tenant.switch(@tenant) do
      feed = Feed.create!(slug: "buy", prompt: "x")
      kept = Item.create!(kind: "text", title: "kept")
      loose = Item.create!(kind: "text", title: "loose")

      feed.items << kept

      assert_equal [ kept ], Item.kept_by("buy").to_a
      assert_not_includes Item.kept_by("buy"), loose
    end
  end

  test "kept_by an unknown slug is empty rather than everything" do
    Tenant.switch(@tenant) do
      Item.create!(kind: "text", title: "loose")

      assert_empty Item.kept_by("nothing-here")
    end
  end
end
