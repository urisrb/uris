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

  def perform(tenant_id, item_id, run_id = nil)
    tenant = Tenant.find(tenant_id)

    Tenant.switch(tenant) { run&.running! }

    item = Tenant.switch(tenant) do
      Item.includes(references: :resource).find_by(id: item_id)
    end

    return finish_run if item.nil?

    Tenant.switch(tenant) { Analyzer.for(item, run: run).run }

    Tenant.switch(tenant) { run&.progressed!(1) }

    finish_run

    Tenant.switch(tenant) { wake_parent(tenant_id, item) }
  end

  def fail_run(error)
    return if run.nil?

    Tenant.switch(run.tenant) do
      next unless run.reload.open?

      run.finished!(error: "#{error.class}: #{error.message}")
    end
  end

  private

    def finish_run
      return if run.nil?

      Tenant.switch(run.tenant) { run.finished! }
    end

    def run
      return @run if defined?(@run)

      tenant_id, _item_id, run_id = arguments
      return @run = nil if run_id.nil?

      @run = Tenant.switch(Tenant.find(tenant_id)) { Run.find_by(id: run_id) }
    rescue StandardError
      @run = nil
    end

    def wake_parent(tenant_id, item)
      parent = item.parent
      return if parent.nil? || item.analyzed_at.nil?
      return unless parent.children_ready?

      AnalyzeItemJob.start!(tenant_id, parent.id)
    end
end
