require "test_helper"

class SweepRunsJobTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "sweep-#{SecureRandom.hex(4)}", name: "Sweep")
    @other = Tenant.create!(subdomain: "sweep-#{SecureRandom.hex(4)}", name: "Elsewhere")
  end

  def run_finished(tenant, status:, at:)
    Tenant.switch(tenant) do
      run = Run.start!(kind: "analyze", selector: { "id" => 1 })
      run.update_columns(status: status, finished_at: at)
      run
    end
  end

  test "a run that finished before the cutoff is swept" do
    stale = run_finished(@tenant, status: "done", at: 30.days.ago)
    recent = run_finished(@tenant, status: "done", at: 1.day.ago)

    SweepRunsJob.perform_now

    Tenant.switch(@tenant) do
      assert_nil Run.find_by(id: stale.id)
      assert Run.find_by(id: recent.id).present?
    end
  end

  test "a run still open is left alone however old it looks" do
    open = run_finished(@tenant, status: "queued", at: 30.days.ago)

    SweepRunsJob.perform_now

    Tenant.switch(@tenant) { assert Run.find_by(id: open.id).present? }
  end

  test "a failed run is swept like any other closed one, so nothing grows forever" do
    failed = run_finished(@tenant, status: "failed", at: 30.days.ago)

    SweepRunsJob.perform_now

    Tenant.switch(@tenant) { assert_nil Run.find_by(id: failed.id) }
  end

  test "sweeping reaches every tenant rather than the one that happened to be current" do
    mine = run_finished(@tenant, status: "done", at: 30.days.ago)
    theirs = run_finished(@other, status: "done", at: 30.days.ago)

    SweepRunsJob.perform_now

    Tenant.switch(@tenant) { assert_nil Run.find_by(id: mine.id) }
    Tenant.switch(@other) { assert_nil Run.find_by(id: theirs.id) }
  end

  test "a retention of zero sweeps nothing" do
    kept = run_finished(@tenant, status: "done", at: 30.days.ago)

    with_retention(0) { SweepRunsJob.perform_now }

    Tenant.switch(@tenant) { assert Run.find_by(id: kept.id).present? }
  end

  private

    def with_retention(days)
      previous = Rails.configuration.thingies.run_retention
      Rails.configuration.thingies.run_retention = days.days
      yield
    ensure
      Rails.configuration.thingies.run_retention = previous
    end
end
