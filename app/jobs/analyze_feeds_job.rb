class AnalyzeFeedsJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  queue_as :default

  gated_as "analyze"

  def run_id
    arguments[2]
  end

  def build_enumerator(_tenant_id, selector, _run_id = nil, cursor:)
    ids = Feed.matching(selector).pluck(:id)

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(feed_id, _tenant_id, _selector, _run_id = nil)
    Feed.find_by(id: feed_id)&.analyze!(cause: "manual")

    track_iteration
  end
end
