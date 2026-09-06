require "test_helper"

class AttachingTest < ActionDispatch::IntegrationTest
  TYPES = <<~GQL.freeze
    { resourceTypes { type label names syncs brokered capabilities
                      fields { name label kind required secret value } } }
  GQL

  ATTACH = <<~GQL.freeze
    mutation($type: String!, $key: String!, $name: String, $settings: JSON) {
      attachResource(input: { type: $type, key: $key, name: $name, settings: $settings }) {
        resource { id type key name capabilities }
        checkError
      }
    }
  GQL

  ENROLL = <<~GQL.freeze
    mutation($type: String!, $key: String!) {
      enrollResource(input: { type: $type, key: $key }) { url expiresIn }
    }
  GQL

  setup do
    @tenant = Tenant.create!(subdomain: "attach-#{SecureRandom.hex(4)}", name: "Attaching")

    connect!(@tenant)
  end

  teardown do
    ENV.delete("URIS_FILESYSTEM_ROOTS")
  end

  test "every attachable type says what it needs" do
    types = execute(TYPES).dig("data", "resourceTypes")
    named = types.to_h { |held| [ held["type"], held ] }

    assert_includes named.keys, "s3"
    assert_includes named.keys, "imap"
    refute_includes named.keys, "database", "nothing attaches the tenant's own tables by hand"

    imap = named.fetch("imap")

    assert_equal true, imap["syncs"]
    assert_equal false, imap["brokered"]
    assert_equal true, imap.dig("fields", 0, "required")
    assert_equal "INBOX", imap["fields"].find { |f| f["name"] == "mailbox" }["value"]

    password = imap["fields"].find { |f| f["name"] == "password" }

    assert_equal true, password["secret"]
    assert_nil password["value"], "a secret is never handed back, not even an empty one"
  end

  test "a directory is only offered where the server was given roots to allow" do
    refute_includes offered, "filesystem"

    ENV["URIS_FILESYSTEM_ROOTS"] = Dir.mktmpdir("permitted")

    assert_includes offered, "filesystem"
  end

  test "a bucket is attached, and checked once it is" do
    body = execute(ATTACH, variables: {
      type: "s3", key: "books", name: "Books",
      settings: {
        "endpoint" => "http://127.0.0.1:1", "region" => "eu-west-2",
        "access_key_id" => "k", "secret_access_key" => "s"
      }
    })
    attached = body.dig("data", "attachResource", "resource")

    assert_equal "s3", attached["type"]
    assert_equal "books", attached["key"]
    assert_equal [ "storage" ], attached["capabilities"]
    assert_predicate body.dig("data", "attachResource", "checkError"), :present?,
                     "nothing answers at that endpoint, and the resource says so rather than looking fine"

    Tenant.switch(@tenant) do
      held = Resource.find(attached["id"])

      assert_equal "eu-west-2", held.details["region"]
      assert_equal "us-east-1", Resource::S3.attaching[:fields].find { |f| f[:name] == "region" }[:value]
      assert_equal true, held.details["force_path_style"], "a default is taken where nothing was typed"
      assert_equal "s", held.credentials["secret_access_key"]
      assert_not_includes held.details.keys, "secret_access_key"
    end
  end

  test "a key the form never offered is dropped rather than stored" do
    body = execute(ATTACH, variables: {
      type: "rss", key: "news",
      settings: { "url" => "https://example.com/feed.xml", "root" => "/etc", "via_id" => "7" }
    })

    Tenant.switch(@tenant) do
      held = Resource.find(body.dig("data", "attachResource", "resource", "id"))

      assert_equal({ "url" => "https://example.com/feed.xml" }, held.details)
      assert_nil held.via_id
    end
  end

  test "a needed field left empty is refused by name" do
    body = execute(ATTACH, variables: { type: "rss", key: "news", settings: { "url" => "  " } })

    assert_nil body.dig("data", "attachResource")
    assert_match(/Feed URL is needed/, body.dig("errors", 0, "message"))
  end

  test "a nested model name lands where the type reads it" do
    body = execute(ATTACH, variables: {
      type: "openai-compatible", key: "local",
      settings: { "base_url" => "http://127.0.0.1:11434/v1", "models.fast" => "gemma3:4b" }
    })

    Tenant.switch(@tenant) do
      held = Resource.find(body.dig("data", "attachResource", "resource", "id"))

      assert_equal({ "fast" => "gemma3:4b" }, held.details["models"])
    end
  end

  test "a type nobody attaches by hand is refused" do
    body = execute(ATTACH, variables: { type: "database", key: "sneaky" })

    assert_nil body.dig("data", "attachResource")
    assert_match(/not a type that can be attached/, body.dig("errors", 0, "message"))
  end

  test "a brokered type is not attached through the form" do
    body = execute(ATTACH, variables: { type: "oauth-google", key: "drive" })

    assert_nil body.dig("data", "attachResource")
    assert_match(/connected in the browser/, body.dig("errors", 0, "message"))
  end

  test "a brokered type hands back a link to follow, and creates nothing yet" do
    body = execute(ENROLL, variables: { type: "oauth-google", key: "drive" })
    enrolled = body.dig("data", "enrollResource")

    assert_match(%r{/enroll/}, enrolled["url"])
    assert_equal Enrollment::WINDOW.to_i, enrolled["expiresIn"]

    Tenant.switch(@tenant) { assert_equal 0, Resource.count }
  end

  test "attaching needs the command scope, not merely the read one" do
    body = execute(ATTACH, scopes: %w[uris:resources:read],
                           variables: { type: "rss", key: "news",
                                        settings: { "url" => "https://example.com/feed.xml" } })

    assert_nil body.dig("data", "attachResource")
    Tenant.switch(@tenant) { assert_equal 0, Resource.count }
  end

  test "what was attached is audited without any of what was typed into it" do
    execute(ATTACH, variables: {
      type: "rss", key: "news", settings: { "url" => "https://example.com/feed.xml" }
    })

    Tenant.switch(@tenant) do
      event = AuditEvent.find_by(action: "attach_resource")

      assert_equal "ok", event.status
      assert_equal "rss", event.arguments["type"]
      assert_equal "url", event.arguments["set"]
      refute_includes event.arguments.to_s, "example.com"
    end
  end

  private

    def offered
      execute(TYPES).dig("data", "resourceTypes").map { |held| held["type"] }
    end

    def host_for(tenant)
      { "HOST" => "#{tenant.subdomain}.uris.test" }
    end

    def bearer(tenant, scopes: Grant::SCOPES)
      token = issuer.mint(
        subdomain: tenant.subdomain, scopes: scopes,
        audience: "http://#{tenant.subdomain}.uris.test/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end

    def execute(query, variables: nil, scopes: Grant::SCOPES)
      post "/graphql",
           params: { query: query, variables: variables&.to_json }.compact,
           headers: host_for(@tenant).merge(bearer(@tenant, scopes: scopes))

      response.parsed_body
    end
end
