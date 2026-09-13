require "test_helper"

class AnalyzeFeedJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "run-#{SecureRandom.hex(4)}", name: "Analysis runs")

    Tenant.switch(@tenant) do
      @storage = Resource::Database.create!(key: "drop", name: "Drop")
      @storage.upload("notes.txt", "remember the milk")

      @feed = Feed.create!(type: Feed::FILE, key: "notes.txt", title: "notes.txt")
      Reference.record!(feed: @feed, resource: @storage,
                        locator_key: "notes.txt", locator: { "key" => "notes.txt" })
    end
  end

  test "a pass files the feed under its content type, as a feed of its own" do
    Tenant.switch(@tenant) { @feed.analyze! }

    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      assert_equal [ "text/plain" ], @feed.reload.mimes.map(&:key)
      assert_equal 1, Feed.mimes.where(key: "text/plain").count
      assert_empty @feed.tags
    end
  end

  test "a run someone asked for is enqueued ahead of a sync's bulk" do
    Tenant.switch(@tenant) do
      @feed.analyze!(cause: "manual")
      @feed.analyze!(cause: "sync")
    end

    priorities = enqueued_jobs.select { |job| job["job_class"] == "AnalyzeFeedJob" }.map { |job| job["priority"] }

    assert_equal [ Analysis::ASKED_PRIORITY, Analysis::BULK_PRIORITY ], priorities
  end

  test "an address has no bytes to read, so its pass goes straight to the agent" do
    analysis = Tenant.switch(@tenant) do
      Feed.create!(type: Feed::ADDRESS, key: "/buy").tap { |feed| feed.create_schedule!(prompt: "find things") }.analyze!
    end

    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      assert_equal "done", analysis.reload.status
      assert_empty analysis.steps
    end
  end

  test "an address is told the web search it can use, and how to keep what it finds" do
    Tenant.switch(@tenant) do
      Resource::Search.create!(key: "exa", details: { "provider" => "exa" }, credentials: { "api_key" => "k" })
      feed = Feed.create!(type: Feed::ADDRESS, key: "/buy")
      feed.create_schedule!(prompt: "find cool things to buy")

      prompt = AnalyzeFeedJob.new.send(:asked, feed)

      assert_match(/find cool things to buy/, prompt)
      assert_match(/key\s+"exa"/, prompt)
      assert_match(/connect the note to feed #{feed.id}/, prompt)
    end
  end

  test "a question is told to read what a search turns up only when something can read a page" do
    Tenant.switch(@tenant) do
      Resource::Search.create!(key: "exa", details: { "provider" => "exa" }, credentials: { "api_key" => "k" })

      searched_only = AnalyzeFeedJob.new.send(:web, @feed)

      assert_match(/markdown link/, searched_only)
      assert_no_match(/only a lead/, searched_only)
      assert_no_match(/do=get/, searched_only)

      Resource::Curl.create!(key: "curl", name: "Curl")

      reading = AnalyzeFeedJob.new.send(:web, @feed)

      assert_match(/only a lead/, reading)
      assert_match(/key "curl"/, reading)
    end
  end

  test "an answer drawn from search results alone is turned back only when a page could have been read" do
    searched = Agent::Dispatch::Result.new(name: "resource", arguments: { "do" => "search", "key" => "exa" },
                                           content: "{}", ok: true, error: nil)
    failed = searched.with(arguments: { "do" => "get", "key" => "curl" }, ok: false)
    read = searched.with(arguments: { "do" => "get", "key" => "curl" })

    Tenant.switch(@tenant) do
      assert_nil AnalyzeFeedJob.new.send(:unread, [])

      Resource::Search.create!(key: "exa", details: { "provider" => "exa" }, credentials: { "api_key" => "k" })

      assert_nil AnalyzeFeedJob.new.send(:unread, [ searched ])

      Resource::Curl.create!(key: "curl", name: "Curl")

      assert_match(/without reading any page.*"key":"curl"/, AnalyzeFeedJob.new.send(:unread, [ searched ]))
      assert_match(/without reading any page/, AnalyzeFeedJob.new.send(:unread, [ searched, failed ]))
      assert_nil AnalyzeFeedJob.new.send(:unread, [ searched, read ])
    end
  end

  test "the push to read hands back the exact call for each address the search turned up" do
    results = { count: 2, results: [ { url: "https://hn.algolia.com/about" }, { url: "javascript:alert(1)" } ] }
    searched = Agent::Dispatch::Result.new(name: "resource", arguments: { "do" => "search", "key" => "exa" },
                                           content: results.to_json, ok: true, error: nil)

    Tenant.switch(@tenant) do
      Resource::Curl.create!(key: "curl", name: "Curl")

      pushed = AnalyzeFeedJob.new.send(:unread, [ searched ])

      assert_includes pushed, { do: "get", key: "curl", input: { url: "https://hn.algolia.com/about" } }.to_json
      assert_not_includes pushed, "javascript:"
    end
  end

  test "an answer that found nothing in the catalog and never looked beyond it is sent to the web" do
    opened = Agent::Dispatch::Result.new(name: "feed", arguments: { "id" => @feed.id.to_s },
                                         content: "{}", ok: true, error: nil)
    looked = Agent::Dispatch::Result.new(name: "search", arguments: { "query" => "milk" },
                                         content: "{}", ok: true, error: nil)

    Tenant.switch(@tenant) do
      Resource::Search.create!(key: "exa", details: { "provider" => "exa" }, credentials: { "api_key" => "k" })

      assert_match(/look at the web.*key "exa"/, AnalyzeFeedJob.new.send(:unread, [ looked ]))
      assert_nil AnalyzeFeedJob.new.send(:unread, [ looked, opened ])
    end
  end

  test "asking for an analysis opens one before the job is enqueued" do
    analysis = nil

    assert_enqueued_with(job: AnalyzeFeedJob) do
      Tenant.switch(@tenant) { analysis = @feed.analyze! }
    end

    Tenant.switch(@tenant) do
      assert_equal "manual", analysis.cause
      assert_equal "queued", analysis.status
      assert_equal @feed, analysis.feed
    end
  end

  test "the analysis finishes when the pass does, and the feed is read" do
    analysis = Tenant.switch(@tenant) { @feed.analyze! }

    perform_enqueued_jobs(only: AnalyzeFeedJob)

    Tenant.switch(@tenant) do
      finished = analysis.reload

      assert_equal "done", finished.status
      assert finished.finished_at.present?
      assert finished.steps.key?("text")
      assert @feed.reload.analyzed_at.present?
    end
  end

  test "the job carries its analysis rather than opening a second one" do
    analysis = Tenant.switch(@tenant) { @feed.analyze! }

    enqueued = enqueued_jobs.find { |job| job["job_class"] == "AnalyzeFeedJob" }

    assert_equal [ @tenant.id, @feed.id, analysis.id ], enqueued["arguments"]
  end

  test "an analysis whose feed has gone away goes with it rather than being left open" do
    Tenant.switch(@tenant) { @feed.analyze! }
    Tenant.switch(@tenant) { @feed.destroy! }

    assert_nothing_raised { perform_enqueued_jobs(only: AnalyzeFeedJob) }

    Tenant.switch(@tenant) { assert_equal 0, Analysis.count }
  end

  test "bytes that may come back leave the analysis open while the job retries" do
    analysis = Tenant.switch(@tenant) { @feed.analyze! }

    Tenant.switch(@tenant) { ResourceBlob.find_by!(key: "notes.txt").destroy! }

    assert_enqueued_with(job: AnalyzeFeedJob) do
      Tenant.switch(@tenant) { AnalyzeFeedJob.perform_now(@tenant.id, @feed.id, analysis.id) }
    end

    Tenant.switch(@tenant) { assert analysis.reload.open?, "an analysis being retried is not finished" }
  end

  test "giving up on a feed closes its analysis with the reason" do
    analysis = Tenant.switch(@tenant) { @feed.analyze! }

    Tenant.switch(@tenant) do
      job = AnalyzeFeedJob.new(@tenant.id, @feed.id, analysis.id)
      job.fail_analysis(Resource::Failed.new("drop: no blob at notes.txt"))
    end

    Tenant.switch(@tenant) do
      failed = analysis.reload

      assert_equal "failed", failed.status
      assert_match(/no blob at notes.txt/, failed.error)
      assert failed.finished_at.present?
    end
  end

  test "an analysis marked running survives the pass that raised under it" do
    analysis = Tenant.switch(@tenant) { @feed.analyze! }

    Tenant.switch(@tenant) { ResourceBlob.find_by!(key: "notes.txt").destroy! }

    Tenant.switch(@tenant) { AnalyzeFeedJob.perform_now(@tenant.id, @feed.id, analysis.id) }

    Tenant.switch(@tenant) do
      assert_equal "running", analysis.reload.status,
                   "Tenant.switch is a savepoint; marking it running must not roll back with the read"
      assert_nil @feed.reload.analyzed_at
    end
  end

  test "a job given no analysis opens one rather than reading into nowhere" do
    Tenant.switch(@tenant) { AnalyzeFeedJob.perform_now(@tenant.id, @feed.id) }

    Tenant.switch(@tenant) do
      assert @feed.reload.analyzed_at.present?
      assert_equal 1, Analysis.count
      assert_equal "done", Analysis.last.status
    end
  end
end
