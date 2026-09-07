require "test_helper"

class AnalyzeItemJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "run-#{SecureRandom.hex(4)}", name: "Analysis runs")

    Tenant.switch(@tenant) do
      @storage = Resource::Database.create!(key: "drop", name: "Drop")
      @storage.upload("notes.txt", "remember the milk")

      @item = Item.create!(kind: "text", title: "notes.txt")
      Reference.record!(item: @item, resource: @storage,
                             locator_key: "notes.txt", locator: { "key" => "notes.txt" })
    end
  end

  test "asking for an analysis opens a run before the job is enqueued" do
    run = nil

    assert_enqueued_with(job: AnalyzeItemJob) do
      Tenant.switch(@tenant) { run = AnalyzeItemJob.start!(@tenant.id, @item.id) }
    end

    Tenant.switch(@tenant) do
      assert_equal "analyze", run.kind
      assert_equal "queued", run.status
      assert_equal({ "id" => @item.id }, run.selector)
    end
  end

  test "the run finishes when the analysis does, and counts the item it read" do
    run = Tenant.switch(@tenant) { AnalyzeItemJob.start!(@tenant.id, @item.id) }

    perform_enqueued_jobs(only: AnalyzeItemJob)

    Tenant.switch(@tenant) do
      finished = run.reload

      assert_equal "done", finished.status
      assert_equal 1, finished.processed
      assert finished.finished_at.present?
      assert @item.reload.analyzed_at.present?
    end
  end

  test "a retry carries its run rather than opening a second one" do
    run = Tenant.switch(@tenant) { AnalyzeItemJob.start!(@tenant.id, @item.id) }

    enqueued = enqueued_jobs.find { |job| job["job_class"] == "AnalyzeItemJob" }

    assert_equal [ @tenant.id, @item.id, run.id ], enqueued["arguments"]
  end

  test "a run whose item has gone away is closed rather than left open" do
    run = Tenant.switch(@tenant) { AnalyzeItemJob.start!(@tenant.id, @item.id) }
    Tenant.switch(@tenant) { @item.destroy! }

    perform_enqueued_jobs(only: AnalyzeItemJob)

    Tenant.switch(@tenant) { assert_equal "done", run.reload.status }
  end

  test "bytes that may come back leave the run open while the job retries" do
    run = Tenant.switch(@tenant) { AnalyzeItemJob.start!(@tenant.id, @item.id) }

    Tenant.switch(@tenant) { ResourceBlob.find_by!(key: "notes.txt").destroy! }

    assert_enqueued_with(job: AnalyzeItemJob) do
      Tenant.switch(@tenant) { AnalyzeItemJob.perform_now(@tenant.id, @item.id, run.id) }
    end

    Tenant.switch(@tenant) { assert run.reload.open?, "a run being retried is not finished" }
  end

  test "giving up on an item closes its run with the reason" do
    run = Tenant.switch(@tenant) { AnalyzeItemJob.start!(@tenant.id, @item.id) }

    Tenant.switch(@tenant) do
      job = AnalyzeItemJob.new(@tenant.id, @item.id, run.id)
      job.fail_run(Resource::Failed.new("drop: no blob at notes.txt"))
    end

    Tenant.switch(@tenant) do
      failed = run.reload

      assert_equal "failed", failed.status
      assert_match(/no blob at notes.txt/, failed.error)
      assert failed.finished_at.present?
    end
  end

  test "a run marked running survives the analysis that raised under it" do
    run = Tenant.switch(@tenant) { AnalyzeItemJob.start!(@tenant.id, @item.id) }

    Tenant.switch(@tenant) { ResourceBlob.find_by!(key: "notes.txt").destroy! }

    Tenant.switch(@tenant) { AnalyzeItemJob.perform_now(@tenant.id, @item.id, run.id) }

    Tenant.switch(@tenant) do
      assert_equal "running", run.reload.status,
                   "Tenant.switch is a savepoint; marking the run must not roll back with the read"
      assert_nil @item.reload.analyzed_at
    end
  end

  test "analysis without a run still reads the item" do
    AnalyzeItemJob.perform_now(@tenant.id, @item.id)

    Tenant.switch(@tenant) do
      assert @item.reload.analyzed_at.present?
      assert_equal 0, Run.count
    end
  end
end
