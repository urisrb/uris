class AnalyzeThingsJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  queue_as :default

  def run_id
    arguments[2]
  end

  def build_enumerator(tenant_id, selector, _run_id = nil, cursor:)
    ids = Tenant.switch(Tenant.find(tenant_id)) { Thing.matching(selector).pluck(:id) }

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(thing_id, tenant_id, _selector, _run_id = nil)
    AnalyzeThingJob.perform_later(tenant_id, thing_id)

    track_iteration
  end
end
