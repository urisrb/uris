class ReindexItemsJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  PAGE = 200

  queue_as :default

  gated_as "reindex"

  def run_id
    arguments[2]
  end

  def build_enumerator(_tenant_id, _index = nil, _run_id = nil, cursor:)
    pages = Enumerator.new do |yielder|
      after = cursor

      loop do
        batch = page_after(after)
        break if batch.empty?

        after = batch.last.id.to_s
        yielder.yield(batch, after)

        break if batch.size < PAGE
      end
    end

    enumerator_builder.wrap(enumerator_builder, pages)
  end

  def each_iteration(items, _tenant_id, index = nil, _run_id = nil)
    return track_iteration(items.size) if dry_run?

    SearchIndex.index_all(items, into: index.presence || SearchIndex.alias_name)

    track_iteration(items.size)
  end

  private

    def page_after(after)
      scope = Item.includes(:references, children: :references).order(:id).limit(PAGE)
      scope = scope.where("items.id > ?", after.to_i) if after.present?
      scope.to_a
    end
end
