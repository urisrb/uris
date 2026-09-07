require "test_helper"

class DatabaseResourceTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "db-#{SecureRandom.hex(4)}", name: "Database")

    Tenant.switch(@tenant) do
      @storage = Resource::Database.create!(key: "database", name: "Default storage")
    end
  end

  test "the stored type is the domain type" do
    assert_equal "database", @storage.read_attribute(:type)
    assert_equal [ :storage ], @storage.capabilities
  end

  test "it needs no endpoint and no credentials to work" do
    Tenant.switch(@tenant) do
      assert @storage.check!
      assert_empty @storage.credentials
    end
  end

  test "bytes go in and come back out" do
    Tenant.switch(@tenant) do
      locator = @storage.upload("notes/hello.md", "# Hello\n")

      assert_equal({ "key" => "notes/hello.md" }, locator)
      assert_equal "# Hello\n", @storage.download(locator).read
    end
  end

  test "uploading the same key twice replaces rather than duplicates" do
    Tenant.switch(@tenant) do
      @storage.upload("a.txt", "first")
      @storage.upload("a.txt", "second")

      assert_equal 1, @storage.blobs.count
      assert_equal "second", @storage.download("key" => "a.txt").read
    end
  end

  test "a missing blob is a resource failure, so the retry policy applies" do
    Tenant.switch(@tenant) do
      assert_raises(Resource::Failed) { @storage.download("key" => "nope") }
    end
  end

  test "it is syncable, so generated content catalogues itself" do
    Tenant.switch(@tenant) do
      @storage.upload("AGENTS.md", "how to work on this repo")
      @storage.upload("notes.txt", "plain")
    end

    assert @storage.syncable?
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @storage.id) }

    Tenant.switch(@tenant) do
      assert_equal 2, Item.referencing(@storage.id).count
      assert_equal "how to work on this repo", item_at("AGENTS.md").download.read
    end
  end

  test "an item can hold the raw file and a generated document side by side" do
    Tenant.switch(@tenant) do
      source = Resource::S3.create!(key: "bucket", details: { "endpoint" => "http://127.0.0.1:1" })
      item = create_item(kind: "pdf", title: "Contract", resource: source, locator_key: "contract.pdf")

      @storage.upload("contract.AGENTS.md", "what this contract says")
      item.references.create!(resource: @storage, locator_key: "contract.AGENTS.md",
                               locator: { "key" => "contract.AGENTS.md" })

      places = item.references.reset.map { |reference| reference.resource.class.sti_name }

      assert_equal %w[s3 database], places
      assert_equal "what this contract says", item.references.last.download.read
    end
  end

  test "tenants cannot read each other's blobs" do
    other = Tenant.create!(subdomain: "db-#{SecureRandom.hex(4)}", name: "Other")

    Tenant.switch(@tenant) { @storage.upload("secret.txt", "mine") }

    Tenant.switch(other) do
      assert_equal 0, ResourceBlob.count
    end
  end
end
