class SyncResourceJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  queue_as :sync

  gated_as "sync"

  rescue_from(StandardError) do |error|
    fail_run(error)
    abandon_sync
    raise error
  end

  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.fail_run(error)
    job.abandon_sync
  end

  on_complete :release_sync

  def run_id
    arguments[2]
  end

  def build_enumerator(_tenant_id, resource_id, _run_id = nil, cursor:)
    resource = resource_for(resource_id)

    objects = Enumerator.new do |yielder|
      started_at = cursor

      resource.each_page(cursor: cursor) do |page, next_cursor|
        page.each_with_index do |object, index|
          yielder.yield(object, index == page.size - 1 ? next_cursor : started_at)
        end

        started_at = next_cursor
      end
    end

    enumerator_builder.wrap(enumerator_builder, objects)
  end

  def abandon_sync
    Resource.find_by(id: arguments[1])&.abandon_sync!
  end

  def gate_reference
    resource_for(arguments[1])
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def each_iteration(object, tenant_id, resource_id, _run_id = nil)
    resource = resource_for(resource_id)
    locator_key = resource.locator_key_for(object)

    return track_iteration if dry_run?

    reference = Reference.discover!(
      resource: resource,
      locator: resource.locator_for(object),
      locator_key: locator_key,
      mime: resource.mime_for(object),
      title: resource.title_for(object)
    )

    reference.feed.analyze!(cause: "sync") if reference.analyzed_at.nil?

    track_iteration
  end

  private

    def release_sync
      @resource&.release_sync!
    end

    def resource_for(resource_id)
      @resource ||= Resource.find(resource_id)
    end
end
