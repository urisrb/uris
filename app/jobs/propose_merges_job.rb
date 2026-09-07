class ProposeMergesJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  PAGE = 200

  queue_as :default

  gated_as "dedupe"

  def run_id
    arguments[1]
  end

  def build_enumerator(_tenant_id, _run_id = nil, cursor:)
    groups = Enumerator.new do |yielder|
      after = cursor

      loop do
        batch = Blocking.groups_after(after, limit: PAGE)
        break if batch.empty?

        after = batch.last["blocking_key"]
        batch.each { |group| yielder.yield(group, group["blocking_key"]) }

        break if batch.size < PAGE
      end
    end

    enumerator_builder.wrap(enumerator_builder, groups)
  end

  def each_iteration(group, _tenant_id, _run_id = nil)
    return track_iteration if dry_run?

    propose(group)

    track_iteration
  end

  private

    def propose(group)
      ids = Array(group["item_ids"]).map(&:to_i).sort
      held = MergeProposal.find_by(blocking_key: group["blocking_key"], status: "open")

      return held.update!(item_ids: ids) if held

      MergeProposal.create!(
        blocking_key: group["blocking_key"],
        reason: group["reason"],
        item_ids: ids
      )
    end
end
