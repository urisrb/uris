require "test_helper"

class UploadsTest < ActionDispatch::IntegrationTest
  setup do
    SearchIndex.reset!

    @allowed = Pathname.new(Dir.mktmpdir("permitted"))
    @root = @allowed + "drop"
    @root.mkpath

    ENV["THINGS_FILESYSTEM_ROOTS"] = @allowed.to_s

    @tenant = Tenant.create!(subdomain: "up-#{SecureRandom.hex(4)}", name: "Uploads")
    @other = Tenant.create!(subdomain: "up-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(@tenant) do
      @storage = Resource::Filesystem.create!(
        key: "drop-#{SecureRandom.hex(4)}", name: "Drop", details: { "root" => @root.to_s }
      )
      @storage.make_default_storage!
    end

    connect!(@tenant)
    connect!(@other)
  end

  teardown do
    ENV.delete("THINGS_FILESYSTEM_ROOTS")
    FileUtils.remove_entry(@allowed) if @allowed.exist?
  end

  test "a dropped file lands in default storage and is catalogued" do
    upload "march.pdf", "contents of march"

    assert_response :success

    body = response.parsed_body

    assert_equal "pdf", body["kind"]
    assert_equal "march.pdf", body["path"]
    assert_equal @storage.key, body["resource"]
    assert_equal "contents of march", (@root + "march.pdf").read

    Tenant.switch(@tenant) do
      thing = thing_at("march.pdf")

      assert_equal "pdf", thing.kind
      assert_equal "march.pdf", thing.title
      assert_equal @storage.id, thing.resource.id
    end
  end

  test "a dropped file is queued for analysis, with a run to watch it by" do
    assert_enqueued_jobs 1, only: AnalyzeThingJob do
      upload "march.pdf", "contents of march"
    end

    assert_response :success

    Tenant.switch(@tenant) do
      run = Run.find(response.parsed_body["run_id"])

      assert_equal "analyze", run.kind
      assert_equal "queued", run.status
      assert_equal({ "id" => thing_at("march.pdf").id }, run.selector)
    end
  end

  test "a dropped folder keeps its shape as the locator key" do
    upload "beach.jpg", "jpeg bytes", path: "photos/2024/beach.jpg"

    assert_response :success
    assert_equal "photos/2024/beach.jpg", response.parsed_body["path"]
    assert_equal "jpeg bytes", (@root + "photos/2024/beach.jpg").read

    Tenant.switch(@tenant) { assert_equal "image", thing_at("photos/2024/beach.jpg").kind }
  end

  test "a path that climbs out of the resource is flattened, not followed" do
    upload "escape.txt", "nope", path: "../../etc/escape.txt"

    assert_response :success
    assert_equal "etc/escape.txt", response.parsed_body["path"]
    assert_equal "nope", (@root + "etc/escape.txt").read
    assert_not (@allowed.parent + "etc/escape.txt").exist?
  end

  test "a path with nothing usable left in it is refused" do
    upload "..", "nope", path: "../.."

    assert_response :unprocessable_content
    assert_match(/not a usable path/, response.parsed_body["error"])
  end

  test "dropping the same path twice updates one thing rather than making two" do
    upload "notes.txt", "first"
    upload "notes.txt", "second"

    assert_response :success
    assert_equal "second", (@root + "notes.txt").read

    Tenant.switch(@tenant) do
      assert_equal 1, Thing.count
      assert_equal 1, ThingReference.where(locator_key: "notes.txt").count
    end
  end

  test "a tenant with no default storage is told so rather than guessing one" do
    Tenant.switch(@tenant) { @storage.update!(default_storage: false) }

    upload "march.pdf", "contents"

    assert_response :unprocessable_content
    assert_match(/no default storage/, response.parsed_body["error"])
    Tenant.switch(@tenant) { assert_equal 0, Thing.count }
  end

  test "a token that may read but not write cannot drop anything" do
    upload "march.pdf", "contents", scopes: [ "things:catalog:read" ]

    assert_response :unauthorized
    Tenant.switch(@tenant) { assert_equal 0, Thing.count }
  end

  test "a token minted for another tenant cannot drop into this one" do
    post "/uploads",
         params: { file: uploaded("march.pdf", "contents") },
         headers: host_for(@tenant).merge(bearer(@other))

    assert_response :unauthorized
    Tenant.switch(@tenant) { assert_equal 0, Thing.count }
  end

  private

    def upload(name, contents, path: nil, scopes: Grant::SCOPES)
      post "/uploads",
           params: { file: uploaded(name, contents), path: path }.compact,
           headers: host_for(@tenant).merge(bearer(@tenant, scopes: scopes))
    end

    def uploaded(name, contents)
      file = Tempfile.new([ "drop", File.extname(name) ])
      file.binmode
      file.write(contents)
      file.rewind

      Rack::Test::UploadedFile.new(file.path, "application/octet-stream", original_filename: name)
    end

    def host_for(tenant)
      { "HOST" => "#{tenant.subdomain}.things.test" }
    end

    def bearer(tenant, scopes: Grant::SCOPES)
      token = issuer.mint(
        subdomain: tenant.subdomain, scopes: scopes,
        audience: "http://#{tenant.subdomain}.things.test/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end
end
