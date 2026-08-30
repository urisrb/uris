require "test_helper"

class GatedIterationTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    ENV["THINGS_FILESYSTEM_ROOTS"] = Dir.tmpdir

    @root = Pathname.new(Dir.mktmpdir("gated"))
    6.times { |index| (@root + "file-#{index}.txt").write("contents #{index}") }

    @tenant = Tenant.create!(subdomain: "gated-#{SecureRandom.hex(4)}", name: "Gated")

    Tenant.switch(@tenant) do
      @resource = Resource::Filesystem.create!(
        key: "gated-#{SecureRandom.hex(4)}", details: { "root" => @root.to_s }
      )
    end
  end

  teardown do
    ENV.delete("THINGS_FILESYSTEM_ROOTS")
    FileUtils.remove_entry(@root) if @root.exist?
  end

  test "an open gate catalogues everything, as before" do
    run = start_sync

    Tenant.switch(@tenant) do
      assert_equal 6, Thing.count
      assert_equal "done", run.reload.status
    end
  end

  test "a closed gate stops the run before it catalogues anything" do
    Tenant.switch(@tenant) { Gate.set!(key: "sync", enabled: false) }

    run = start_sync

    Tenant.switch(@tenant) do
      assert_equal 0, Thing.count
      assert_equal "gated", run.reload.status
    end
  end

  test "a gated-off sync releases the resource it had claimed" do
    Tenant.switch(@tenant) do
      Gate.set!(key: "sync", enabled: false)
      @resource.claim_sync!

      assert @resource.syncing?
    end

    start_sync

    Tenant.switch(@tenant) do
      assert_not @resource.reload.syncing?, "the gate stranded the resource lock"
      assert_nil @resource.sync_started_at
    end
  end

  test "a gate on one resource leaves the others alone" do
    other = nil

    Tenant.switch(@tenant) do
      other = Resource::Filesystem.create!(
        key: "open-#{SecureRandom.hex(4)}", details: { "root" => @root.to_s }
      )
      Gate.set!(key: "sync", reference: @resource, enabled: false)
    end

    start_sync
    Tenant.switch(@tenant) { assert_equal 0, Thing.count }

    SyncResourceJob.perform_now(@tenant.id, other.id, nil)
    Tenant.switch(@tenant) { assert_equal 6, Thing.count }
  end

  test "a dry run reports what it walked and catalogues none of it" do
    Tenant.switch(@tenant) { Gate.set!(key: "sync", enabled: true, live: false) }

    run = start_sync

    Tenant.switch(@tenant) do
      assert_equal 0, Thing.count
      assert_equal 6, run.reload.processed
      assert_equal "done", run.status
    end
  end

  test "the operator switch stops a run no tenant asked to stop" do
    ENV[Gate::SHUT] = "1"

    begin
      run = start_sync

      Tenant.switch(@tenant) do
        assert_equal 0, Thing.count
        assert_equal "gated", run.reload.status
      end
    ensure
      ENV.delete(Gate::SHUT)
    end
  end

  private

    def start_sync
      run = Tenant.switch(@tenant) { Run.start!(kind: "sync", resource: @resource) }
      SyncResourceJob.perform_now(@tenant.id, @resource.id, run.id)
      run
    end
end
