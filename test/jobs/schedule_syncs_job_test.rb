require "test_helper"

class Resource
  class Inference < Resource
    def self.capabilities
      [ :inference ]
    end
  end
end

class ScheduleSyncsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @tenant = Tenant.create!(subdomain: "sched-#{SecureRandom.hex(4)}", name: "Scheduled")
    @other = Tenant.create!(subdomain: "unsched-#{SecureRandom.hex(4)}", name: "Unscheduled")

    Tenant.switch(@tenant) { @storage = Resource::Database.create!(key: "database", name: "Storage") }
    Tenant.switch(@other) { @theirs = Resource::Database.create!(key: "database", name: "Theirs") }
  end

  test "a resource runs only when asked until it is given an interval" do
    Tenant.switch(@tenant) do
      assert_nil @storage.next_sync_at
      assert_empty Resource.due_for_sync

      @storage.update!(sync_interval: 5.minutes.to_i)

      assert_in_delta Time.current, @storage.next_sync_at, 5
      assert_equal [ @storage ], Resource.due_for_sync.to_a
    end
  end

  test "an interval cannot be set on a resource that cannot sync" do
    Tenant.switch(@tenant) do
      gpu = Resource::Inference.new(key: "gpu-box", name: "GPU", sync_interval: 5.minutes.to_i)

      assert_not gpu.valid?
      assert_match(/cannot sync/, gpu.errors.full_messages.join)
    end
  end

  test "an interval below the minimum is refused" do
    Tenant.switch(@tenant) do
      @storage.sync_interval = 30

      assert_not @storage.valid?
    end
  end

  test "the scheduler enqueues a sync for every due resource" do
    Tenant.switch(@tenant) { @storage.update!(sync_interval: 5.minutes.to_i) }

    assert_enqueued_with(job: SyncResourceJob,
                         args: ->(args) { args.first(2) == [ @tenant.id, @storage.id ] }) do
      ScheduleSyncsJob.perform_now
    end

    Tenant.switch(@tenant) do
      run = Run.newest_first.first

      assert_equal "sync", run.kind
      assert_equal "queued", run.status
      assert_equal @storage, run.resource
    end
  end

  test "a resource whose next sync is still ahead is left alone" do
    Tenant.switch(@tenant) do
      @storage.update!(sync_interval: 5.minutes.to_i, next_sync_at: 1.hour.from_now)
    end

    assert_no_enqueued_jobs(only: SyncResourceJob) { ScheduleSyncsJob.perform_now }
  end

  test "a sync already running is not started a second time" do
    Tenant.switch(@tenant) { @storage.update!(sync_interval: 5.minutes.to_i) }

    assert_enqueued_jobs 1, only: SyncResourceJob do
      2.times { ScheduleSyncsJob.perform_now }
    end

    Tenant.switch(@tenant) { assert @storage.reload.syncing? }
  end

  test "a sync that never finished is reclaimed once it is old enough to be abandoned" do
    Tenant.switch(@tenant) do
      @storage.update!(sync_interval: 5.minutes.to_i)
      @storage.update_columns(sync_started_at: (Resource::SYNC_ABANDONED_AFTER + 1.hour).ago)

      assert_not @storage.reload.syncing?
    end

    assert_enqueued_jobs 1, only: SyncResourceJob do
      ScheduleSyncsJob.perform_now
    end
  end

  test "finishing a sync releases the lock and moves the next one an interval out" do
    Tenant.switch(@tenant) do
      @storage.update!(sync_interval: 5.minutes.to_i)
      @storage.claim_sync!

      assert @storage.syncing?

      @storage.release_sync!
      @storage.reload

      assert_nil @storage.sync_started_at
      assert_not_nil @storage.synced_at
      assert_in_delta 5.minutes.from_now, @storage.next_sync_at, 5
    end

    assert_no_enqueued_jobs(only: SyncResourceJob) { ScheduleSyncsJob.perform_now }
  end

  test "the next sync sits on the interval's grid, so a slow one does not push the cadence out" do
    started = Time.zone.parse("2026-08-30 05:51:00")

    Tenant.switch(@tenant) do
      @storage.update!(sync_interval: 60, next_sync_at: started)

      travel_to(started + 3.seconds) { @storage.release_sync! }

      assert_equal started + 1.minute, @storage.reload.next_sync_at
    end
  end

  test "a resource left unscheduled for a long time catches up rather than replaying every missed run" do
    started = Time.zone.parse("2026-08-30 05:51:00")

    Tenant.switch(@tenant) do
      @storage.update!(sync_interval: 60, next_sync_at: started)

      travel_to(started + 1.hour) { @storage.release_sync! }

      assert_equal started + 61.minutes, @storage.reload.next_sync_at
    end
  end

  test "the sync job itself releases the lock when it runs out of pages" do
    Tenant.switch(@tenant) do
      @storage.update!(sync_interval: 5.minutes.to_i)
      @storage.claim_sync!
    end

    SyncResourceJob.perform_now(@tenant.id, @storage.id)

    Tenant.switch(@tenant) do
      assert_not @storage.reload.syncing?
      assert_in_delta 5.minutes.from_now, @storage.next_sync_at, 5
    end
  end

  test "one tenant's schedule never starts another tenant's sync" do
    Tenant.switch(@tenant) { @storage.update!(sync_interval: 5.minutes.to_i) }

    assert_enqueued_jobs 1, only: SyncResourceJob do
      ScheduleSyncsJob.perform_now
    end

    Tenant.switch(@other) { assert_nil @theirs.reload.sync_started_at }
  end
end
