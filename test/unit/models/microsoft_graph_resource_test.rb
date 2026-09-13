require "test_helper"
require "masks/client/delegations/fake"

class MicrosoftGraphResourceTest < ActiveSupport::TestCase
  API = "https://graph.microsoft.com/v1.0".freeze

  setup do
    SearchIndex.reset!

    @masks = Delegations.fake = Masks::Client::Delegations::Fake.new

    @tenant = Tenant.create!(subdomain: "ms-#{SecureRandom.hex(4)}", name: "Microsoft")

    started = @masks.start(provider: "microsoft")
    held = @masks.finish(params: @masks.approve(started, subject: "ash"), started: started)

    Tenant.switch(@tenant) do
      @resource = Resource::MicrosoftGraph.create!(key: "onedrive", name: "OneDrive")
      @resource.connect!(held, by: "ash")
    end
  end

  teardown do
    Delegations.fake = nil
  end

  test "the stored type is microsoft-graph, it connects through masks, and it syncs" do
    assert_equal "microsoft-graph", @resource.type
    assert @resource.delegated?
    assert_equal "microsoft", @resource.provider_key
    assert @resource.syncable?
  end

  test "no credential is ever typed in — the form asks for a folder and nothing else" do
    assert_equal [ "folder" ], Resource::MicrosoftGraph.attaching[:fields].map { |field| field[:name] }
    assert_empty Resource::MicrosoftGraph.attaching[:fields].select { |field| field[:secret] }
  end

  test "the token masks releases is what reaches Microsoft" do
    stub_request(:get, "#{API}/me").to_return(json_response(id: "u1", userPrincipalName: "ash@acme.test"))
    stub_request(:get, "#{API}/me/drive").to_return(json_response(id: "d1"))

    Tenant.switch(@tenant) { assert @resource.check! }

    assert_requested :get, "#{API}/me", headers: { "Authorization" => "Bearer microsoft-access-1" }
  end

  test "an account with no drive is unusable, and says which account" do
    stub_request(:get, "#{API}/me").to_return(json_response(id: "u1", userPrincipalName: "ash@acme.test"))
    stub_request(:get, "#{API}/me/drive").to_return(json_response({}))

    error = Tenant.switch(@tenant) { assert_raises(Resource::Unusable) { @resource.check! } }

    assert_match(/ash@acme\.test/, error.message)
  end

  test "a delta page hands back its own next link as the cursor" do
    stub_request(:get, "#{API}/me/drive/root/delta")
      .to_return(json_response(value: [ file("report.pdf") ],
                      "@odata.nextLink": "#{API}/me/drive/root/delta?token=abc"))

    stub_request(:get, "#{API}/me/drive/root/delta?token=abc")
      .to_return(json_response(value: [ file("notes.txt") ], "@odata.deltaLink": "#{API}/delta?token=done"))

    seen = []

    Tenant.switch(@tenant) { @resource.each_page { |batch, cursor| seen << [ batch.length, cursor ] } }

    assert_equal [ [ 1, "#{API}/me/drive/root/delta?token=abc" ], [ 1, nil ] ], seen
  end

  test "a resumed sync asks for the page it had not reached, not the first one" do
    stub_request(:get, "#{API}/me/drive/root/delta?token=abc")
      .to_return(json_response(value: [ file("notes.txt") ]))

    Tenant.switch(@tenant) do
      @resource.each_page(cursor: "#{API}/me/drive/root/delta?token=abc") { |_batch, _cursor| nil }
    end

    assert_not_requested :get, "#{API}/me/drive/root/delta"
  end

  test "folders and deletions are not items, and a file is keyed on its path" do
    stub_request(:get, "#{API}/me/drive/root/delta").to_return(json_response(value: [
      file("report.pdf", path: "/drive/root:/Invoices"),
      { "id" => "f1", "name" => "Invoices", "folder" => { "childCount" => 2 } },
      { "id" => "g1", "name" => "gone.txt", "deleted" => { "state" => "deleted" } }
    ]))

    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      assert_equal 1, Feed.files.count
      assert_equal "Invoices/report.pdf", Feed.last.locator_key
      assert_equal "report.pdf", Feed.last.title
      assert_equal "application/pdf", Feed.last.mime, "the mime still comes from the name"
    end
  end

  test "a folder in the details narrows what is catalogued" do
    Tenant.switch(@tenant) { @resource.update!(details: { "folder" => "Invoices" }) }

    stub_request(:get, "#{API}/me/drive/root/delta").to_return(json_response(value: [
      file("report.pdf", path: "/drive/root:/Invoices"),
      file("holiday.jpg", path: "/drive/root:/Photos")
    ]))

    seen = []

    Tenant.switch(@tenant) { @resource.each_page { |batch, _| seen += batch } }

    assert_equal [ "report.pdf" ], seen.map { |entry| entry["name"] }
  end

  test "a changed file is a new version" do
    Tenant.switch(@tenant) do
      assert_equal "ctag-1", @resource.version_for(@resource.locator_for(file("a.pdf", ctag: "ctag-1")))
      assert_equal "ctag-2", @resource.version_for(@resource.locator_for(file("a.pdf", ctag: "ctag-2")))
    end
  end

  test "content follows the redirect Microsoft answers with, unauthenticated" do
    stub_request(:get, "#{API}/me/drive/items/i1/content")
      .to_return(status: 302, headers: { "Location" => "https://acme.sharepoint.test/download/i1" })

    stub_request(:get, "https://acme.sharepoint.test/download/i1")
      .to_return(status: 200, body: "the bytes")

    bytes = Tenant.switch(@tenant) { @resource.download("id" => "i1").read }

    assert_equal "the bytes", bytes
    assert_requested :get, "https://acme.sharepoint.test/download/i1" do |request|
      request.headers["Authorization"].nil?
    end
  end

  test "a redirect pointing back inside the network is refused rather than followed" do
    stub_request(:get, "#{API}/me/drive/items/i1/content")
      .to_return(status: 302, headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })

    Tenant.switch(@tenant) do
      error = assert_raises(Resource::Unusable) { @resource.download("id" => "i1") }

      assert_match(/169\.254\.169\.254|reserved|private/i, error.message)
    end
  end

  test "a token masks released but Microsoft refuses is released once more, then given up on" do
    stub_request(:get, "#{API}/me").to_return(status: 401, body: "{}")

    Tenant.switch(@tenant) do
      assert_raises(Resource::Unusable) { @resource.check! }
    end

    assert_equal 2, @masks.releases, "an expired token is worth one more release"
    assert_requested :get, "#{API}/me", times: 2
  end

  test "OneDrive syncs on its schedule with nobody signed in" do
    stub_request(:get, "#{API}/me/drive/root/delta").to_return(json_response(value: [ file("report.pdf") ]))

    Current.reset
    Tenant.switch(@tenant) do
      @resource.update!(sync_interval: 1.hour.to_i)
      SyncResourceJob.perform_now(@tenant.id, @resource.id)
    end

    assert_nil Current.grant
    assert_equal 1, Tenant.switch(@tenant) { Feed.files.count }
    assert_requested :get, "#{API}/me/drive/root/delta", headers: { "Authorization" => "Bearer microsoft-access-1" }
  end

  private

    def file(name, path: "/drive/root:", ctag: "ctag-1")
      {
        "id" => "i-#{name}", "name" => name, "size" => 120,
        "file" => { "mimeType" => "application/octet-stream" },
        "cTag" => ctag, "lastModifiedDateTime" => "2026-09-01T10:00:00Z",
        "parentReference" => { "path" => path }
      }
    end
end
