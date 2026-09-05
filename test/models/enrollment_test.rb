require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "enrol-#{SecureRandom.hex(4)}", name: "Enrol")
    @other = Tenant.create!(subdomain: "other-#{SecureRandom.hex(4)}", name: "Other")
  end

  def open!(type: "oauth-google", key: "drive", name: "My Drive")
    Tenant.switch(@tenant) { Enrollment.open!(type: type, key: key, name: name) }
  end

  test "the link carries no credential and names only the enrollment" do
    enrollment = open!

    assert_equal "google", enrollment.provider
    assert_match %r{\Ahttps://uris\.test/enroll/}, enrollment.url("https://uris.test")
  end

  test "a token redeems back to what it was opened with" do
    redeemed = Enrollment.redeem(open!.token)

    assert_equal "oauth-google", redeemed.type
    assert_equal "drive", redeemed.key
    assert_equal "My Drive", redeemed.name
    assert_equal @tenant.id, redeemed.tenant_id
  end

  test "a tampered token does not redeem" do
    token = open!.token

    assert_raises(Enrollment::Invalid) { Enrollment.redeem("#{token}x") }
    assert_raises(Enrollment::Invalid) { Enrollment.redeem("nonsense") }
  end

  test "an expired token does not redeem" do
    token = open!.token

    travel Enrollment::WINDOW + 1.minute do
      assert_raises(Enrollment::Invalid) { Enrollment.redeem(token) }
    end
  end

  test "a token from one tenant does not belong to another" do
    redeemed = Enrollment.redeem(open!.token)

    assert redeemed.belongs_to?(@tenant)
    assert_not redeemed.belongs_to?(@other)
  end

  test "claiming creates the resource pointing at the connection" do
    enrollment = Enrollment.redeem(open!.token)

    Tenant.switch(@tenant) do
      resource = enrollment.claim!("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")

      assert_equal "oauth-google", resource.class.sti_name
      assert_equal "drive", resource.key
      assert_equal "My Drive", resource.name
      assert_equal "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", resource.connection_id
    end
  end

  test "claiming twice rebinds the resource rather than duplicating it" do
    Tenant.switch(@tenant) do
      Enrollment.redeem(open!.token).claim!("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
      Enrollment.redeem(open!.token).claim!("ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee")

      assert_equal 1, Resource::OauthGoogle.where(key: "drive").count
      assert_equal "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee",
                   Resource::OauthGoogle.find_by(key: "drive").connection_id
    end
  end

  test "a type that is not brokered cannot be enrolled this way" do
    assert_raises(ArgumentError) { open!(type: "s3", key: "bucket") }
    assert_raises(ArgumentError) { open!(type: "nonsense", key: "x") }
  end
end
