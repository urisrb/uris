class ProposeMergesJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  PAGE = 200

  queue_as :default

  gated_as "dedupe"

  def run_id
    arguments[1]
  end

  def build_enumerator(tenant_id, _run_id = nil, cursor:)
    tenant = Tenant.find(tenant_id)

    groups = Enumerator.new do |yielder|
      after = cursor

      loop do
        batch = Tenant.switch(tenant) { Blocking.groups_after(after, limit: PAGE) }
        break if batch.empty?

        after = batch.last["blocking_key"]
        batch.each { |group| yielder.yield(group, group["blocking_key"]) }

        break if batch.size < PAGE
      end
    end

    enumerator_builder.wrap(enumerator_builder, groups)
  end

  def each_iteration(group, tenant_id, _run_id = nil)
    return track_iteration if dry_run?

    Tenant.switch(tenant_for(tenant_id)) { propose(group) }

    track_iteration
  end

  private

    def propose(group)
      ids = Array(group["thing_ids"]).map(&:to_i).sort
      held = MergeProposal.find_by(blocking_key: group["blocking_key"], status: "open")

      return held.update!(thing_ids: ids) if held

      MergeProposal.create!(
        blocking_key: group["blocking_key"],
        reason: group["reason"],
        thing_ids: ids
      )
    end

    def tenant_for(tenant_id)
      @tenant ||= Tenant.find(tenant_id)
    end
end
