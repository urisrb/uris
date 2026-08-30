class AnalyzeThingJob < ApplicationJob
  queue_as :analysis

  def perform(tenant_id, thing_id)
    tenant = Tenant.find(tenant_id)
    thing = Tenant.switch(tenant) { Thing.includes(:resource).find_by(id: thing_id) }

    return if thing.nil?

    Analyzer.for(thing).run
  end
end
