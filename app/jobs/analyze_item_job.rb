class AnalyzeItemJob < ApplicationJob
  queue_as :analysis

  limits_concurrency to: ENV.fetch("ANALYSIS_PER_TENANT", 2).to_i,
                     key: ->(tenant_id, *) { "analysis/#{tenant_id}" },
                     duration: 30.minutes

  rescue_from(StandardError) do |error|
    fail_run(error)
    raise error
  end

  discard_on(Analyzer::Failed) { |job, error| job.fail_run(error) }
  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.fail_run(error)
  end

  def self.start!(tenant_id, item_id)
    Run.start!(kind: "analyze", selector: { "id" => item_id }).tap do |run|
      perform_later(tenant_id, item_id, run.id)
    end
  end

  def perform(_tenant_id, item_id, _run_id = nil)
    run&.running!

    item = Item.includes(references: :resource).find_by(id: item_id)

    return finish_run if item.nil?

    ActiveRecord::Base.transaction(requires_new: true) { Analyzer.for(item, run: run).run }

    run&.progressed!(1)

    finish_run

    wake_parent(item)
  end

  def fail_run(error)
    return if run.nil?
    return unless run.reload.open?

    run.finished!(error: "#{error.class}: #{error.message}")
  end

  private

    def finish_run
      run&.finished!
    end

    def run
      return @run if defined?(@run)

      @run = Run.find_by(id: arguments[2])
    end

    def wake_parent(item)
      parent = item.parent
      return if parent.nil? || item.analyzed_at.nil?
      return unless parent.children_ready?

      AnalyzeItemJob.start!(item.tenant_id, parent.id)
    end
end
