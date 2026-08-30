class AnalyzeThingsJob < ApplicationJob
  include JobIteration::Iteration

  queue_as :default

  def build_enumerator(tenant_id, selector, cursor:)
    ids = Tenant.switch(Tenant.find(tenant_id)) { Thing.matching(selector).pluck(:id) }

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(thing_id, tenant_id, _selector)
    AnalyzeThingJob.perform_later(tenant_id, thing_id)
  end
end
