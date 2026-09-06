require "test_helper"

class ScheduleFeedsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @tenant = Tenant.create!(subdomain: "feeds-#{SecureRandom.hex(4)}", name: "Feeds")
    @other = Tenant.create!(subdomain: "feeds-#{SecureRandom.hex(4)}", name: "Elsewhere")
  end

  def feed(tenant, **attrs)
    Tenant.switch(tenant) do
      Feed.create!({ slug: "watch-#{SecureRandom.hex(4)}", prompt: "anything new?",
                     role: "agent" }.merge(attrs))
    end
  end

  test "a feed whose next run has come round is started" do
    due = feed(@tenant, interval: 1.hour.to_i, next_run_at: 1.minute.ago)

    assert_enqueued_with(job: RunFeedJob,
                         args: ->(args) { args.first(2) == [ @tenant.id, due.id ] }) do
      ScheduleFeedsJob.perform_now
    end

    Tenant.switch(@tenant) do
      run = Run.newest_first.first

      assert_equal "feed", run.kind
      assert_equal due, run.feed
    end
  end

  test "a feed whose next run is still ahead is left alone" do
    feed(@tenant, interval: 1.hour.to_i, next_run_at: 1.hour.from_now)

    assert_no_enqueued_jobs(only: RunFeedJob) { ScheduleFeedsJob.perform_now }
  end

  test "a feed with no interval only ever runs when asked" do
    feed(@tenant, interval: nil, next_run_at: 1.minute.ago)

    assert_no_enqueued_jobs(only: RunFeedJob) { ScheduleFeedsJob.perform_now }
  end

  test "a paused feed is skipped however overdue it is" do
    feed(@tenant, interval: 1.hour.to_i, next_run_at: 1.day.ago, paused_at: Time.current)

    assert_no_enqueued_jobs(only: RunFeedJob) { ScheduleFeedsJob.perform_now }
  end

  test "scheduling reaches every tenant rather than the one that happened to be current" do
    mine = feed(@tenant, interval: 1.hour.to_i, next_run_at: 1.minute.ago)
    theirs = feed(@other, interval: 1.hour.to_i, next_run_at: 1.minute.ago)

    assert_enqueued_jobs 2, only: RunFeedJob do
      ScheduleFeedsJob.perform_now
    end

    Tenant.switch(@tenant) { assert_equal mine, Run.newest_first.first.feed }
    Tenant.switch(@other) { assert_equal theirs, Run.newest_first.first.feed }
  end

  test "starting a feed moves its next run an interval out, so one tick cannot start it twice" do
    due = feed(@tenant, interval: 1.hour.to_i, next_run_at: 1.minute.ago)

    assert_enqueued_jobs 1, only: RunFeedJob do
      2.times { ScheduleFeedsJob.perform_now }
    end

    Tenant.switch(@tenant) do
      assert_in_delta 1.hour.from_now, due.reload.next_run_at, 5
    end
  end
end
