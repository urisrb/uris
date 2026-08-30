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

    Tenant.switch(tenant) { Analyzer.for(thing).run }
  end
end
