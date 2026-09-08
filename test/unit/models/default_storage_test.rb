require "test_helper"

class Resource
  class Gpu < Resource
    def self.capabilities
      [ :inference ]
    end
  end
end

class DefaultStorageTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "dflt-#{SecureRandom.hex(4)}", name: "Default")
    @other = Tenant.create!(subdomain: "dflt-#{SecureRandom.hex(4)}", name: "Other")

    Tenant.switch(@tenant) do
      @database = Resource::Database.create!(key: "database", name: "Storage")
      @bucket = Resource::S3.create!(key: "bucket", name: "Bucket",
                                     details: { "endpoint" => "http://127.0.0.1:1" })
    end
  end

  test "a tenant has no default storage until one is named" do
    Tenant.switch(@tenant) do
      assert_nil Resource.default_storage
      assert_raises(ArgumentError) { Resource.default_storage! }
    end
  end

  test "naming a default storage resource makes it the one export writes to" do
    Tenant.switch(@tenant) do
      @database.make_default_storage!

      assert_equal @database, Resource.default_storage!
      assert @database.reload.default_storage?
    end
  end

  test "naming a second one unseats the first" do
    Tenant.switch(@tenant) do
      @database.make_default_storage!
      @bucket.make_default_storage!

      assert_equal @bucket, Resource.default_storage!
      assert_not @database.reload.default_storage?
    end
  end

  test "naming the same one twice is not a conflict" do
    Tenant.switch(@tenant) do
      @database.make_default_storage!

      assert_nothing_raised { @database.make_default_storage! }
      assert_equal @database, Resource.default_storage!
    end
  end

  test "a resource that is not storage cannot be the default" do
    Tenant.switch(@tenant) do
      gpu = Resource::Gpu.create!(key: "gpu-box", name: "GPU")

      assert_raises(ArgumentError) { gpu.make_default_storage! }

      gpu.default_storage = true

      assert_not gpu.valid?
    end
  end

  test "the database refuses two defaults for one tenant even if the model is bypassed" do
    Tenant.switch(@tenant) do
      @database.make_default_storage!

      assert_raises(ActiveRecord::RecordNotUnique) do
        Resource.transaction(requires_new: true) do
          Resource.where(id: @bucket.id).update_all(default_storage: true)
        end
      end
    end
  end

  test "one tenant's default is not another tenant's" do
    Tenant.switch(@tenant) { @database.make_default_storage! }

    Tenant.switch(@other) do
      theirs = Resource::Database.create!(key: "database", name: "Theirs")

      assert_nil Resource.default_storage

      theirs.make_default_storage!

      assert_equal theirs, Resource.default_storage!
    end

    Tenant.switch(@tenant) { assert_equal @database, Resource.default_storage! }
  end

  test "an archived default stops being found" do
    Tenant.switch(@tenant) do
      @database.make_default_storage!
      @database.update!(archived_at: Time.current)

      assert_nil Resource.default_storage
    end
  end
end
