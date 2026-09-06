class RunFeedJob < ApplicationJob
  include Gated

  queue_as :default

  gated_as "feed"

  discard_on ActiveRecord::RecordNotFound

  # A feed is one unit of work rather than an iteration over records, so it owns its Run
  # directly instead of through TrackedRun, whose hooks come from JobIteration.
  def perform(tenant_id, feed_id, run_id = nil)
    Tenant.switch(Tenant.find(tenant_id)) do
      feed = Feed.find(feed_id)
      run = Run.find_by(id: run_id)

      run&.running!
      Current.grant = feed.grant

      agent = Agent.new(
        grant: Current.grant, promptable: run, turns: feed.turns_allowed,
        halted: -> { halted?(run) }
      )
      answered = agent.call(feed.prompt)

      # The read phase is over. Writing is ours.
      Feed::Harvest.new(feed: feed, run: run).call(agent.looked_at)

      feed.update!(ran_at: Time.current)
      settle(run, answered)

      answered
    rescue StandardError => e
      run&.finished!(error: "#{e.class}: #{e.message}")
      raise
    end
  ensure
    Current.grant = nil
  end

  private

    def halted?(run)
      run.present? && run.reload.halted?
    end

    def settle(run, answered)
      return if run.nil?

      case answered
      when :halted then nil
      when :ran_out then run.finished!(error: "the agent used every turn without answering")
      else run.finished!
      end
    end
end
