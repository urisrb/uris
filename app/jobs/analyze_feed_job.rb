class AnalyzeFeedJob < ApplicationJob
  queue_as :analysis

  limits_concurrency to: ENV.fetch("ANALYSIS_PER_TENANT", 2).to_i,
                     key: ->(tenant_id, *) { "analysis/#{tenant_id}" },
                     duration: 30.minutes

  rescue_from(StandardError) do |error|
    fail_analysis(error)
    raise error
  end

  discard_on(Analyzer::Failed) { |job, error| job.fail_analysis(error) }
  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.fail_analysis(error)
  end

  def perform(_tenant_id, feed_id, _analysis_id = nil)
    analysis&.running!

    feed = Feed.includes(references: :resource).find_by(id: feed_id)

    return finish if feed.nil?
    return gate_out if analysis&.halted?

    ActiveRecord::Base.transaction(requires_new: true) do
      Analyzer.for(feed, analysis: analysis).run
    end

    filed(feed)
    considered(feed)

    finish

    wake_parent(feed)
  end

  def fail_analysis(error)
    return if analysis.nil?
    return unless analysis.reload.open?

    analysis.finished!(error: "#{error.class}: #{error.message}")
  end

  FILE_PROMPT = <<~TEXT.freeze
    A new thing has just been catalogued. Read it, then connect it to whatever else in the
    catalog belongs beside it — the tags it should be filed under, and any feed it is about.
    Make the connections with the tools rather than describing them, then say in one
    sentence what you filed it as.
  TEXT

  private

    def filed(feed)
      mime = feed.mime
      return if mime.blank?

      feed.connect!(Feed.tag!(mime))
    end

    def considered(feed)
      grant = feed.grant
      agent = Agent.new(grant: grant, analysis: analysis, turns: turns_for(feed),
                        halted: -> { analysis&.halted? })

      return if agent.inference_key.nil?

      Current.grant = grant
      answered = agent.call(asked(feed))
      analysis&.log_info("agent", answered.reason.to_s, answered.said)
    rescue Agent::Refused, Resource::Unusable => e
      analysis&.log_skip("agent", e.message)
    ensure
      Current.grant = nil
    end

    def asked(feed)
      return feed.schedule.prompt if feed.address? && feed.schedule

      "#{FILE_PROMPT}\n\nIt is feed #{feed.id}, called #{feed.title || feed.key}."
    end

    def turns_for(feed)
      feed.schedule&.turns_allowed || Agent::TURNS
    end

    def finish
      analysis&.finished!
    end

    def gate_out
      nil
    end

    def analysis
      return @analysis if defined?(@analysis)

      @analysis = Analysis.find_by(id: arguments[2]) || opened
    end

    def opened
      feed = Feed.find_by(id: arguments[1])

      feed && Analysis.open!(feed: feed, cause: "manual")
    end

    def wake_parent(feed)
      parent = feed.parent
      return if parent.nil? || feed.analyzed_at.nil?
      return unless parent.children_ready?

      parent.analyze!(cause: "sync")
    end
end
