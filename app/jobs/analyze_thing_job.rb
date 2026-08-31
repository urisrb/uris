class AnalyzeThingJob < ApplicationJob
  queue_as :analysis

  limits_concurrency to: ENV.fetch("ANALYSIS_PER_TENANT", 2).to_i,
                     key: ->(tenant_id, _thing_id) { "analysis/#{tenant_id}" },
                     duration: 30.minutes

  discard_on Analyzer::Failed
  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5

  def perform(tenant_id, thing_id)
    tenant = Tenant.find(tenant_id)
    thing = Tenant.switch(tenant) do
      Thing.includes(references: :resource).find_by(id: thing_id)
    end

    return if thing.nil?

    Tenant.switch(tenant) do
      Analyzer.for(thing).run

      wake_parent(tenant_id, thing)
    end
  end

  private

    # A parent that found children returned without analyzing, because its body
    # is the union with theirs and reading it early would index half of it. The
    # last child to finish is what starts it again — a signal rather than a
    # poll, so nothing re-enqueues itself in a loop.
    def wake_parent(tenant_id, thing)
      parent = thing.parent
      return if parent.nil? || thing.analyzed_at.nil?
      return unless parent.children_ready?

      AnalyzeThingJob.perform_later(tenant_id, parent.id)
    end
end
