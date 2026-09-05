class AnalyzeItemsJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  queue_as :default

  gated_as "analyze"

  def run_id
    arguments[2]
  end

  def build_enumerator(tenant_id, selector, _run_id = nil, cursor:)
    ids = Tenant.switch(Tenant.find(tenant_id)) { Item.matching(selector).pluck(:id) }

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(item_id, tenant_id, _selector, _run_id = nil)
    Tenant.switch(Tenant.find(tenant_id)) { AnalyzeItemJob.start!(tenant_id, item_id) }

    track_iteration
  end
end
