class SyncResourceJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  queue_as :sync

  gated_as "sync"

  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.fail_run(error)
  end

  on_complete :release_sync

  def run_id
    arguments[2]
  end

  def build_enumerator(tenant_id, resource_id, _run_id = nil, cursor:)
    resource = resource_for(tenant_id, resource_id)

    objects = Enumerator.new do |yielder|
      resource.each_page(cursor: cursor) do |page, next_cursor|
        page.each { |object| yielder.yield(object, next_cursor) }
      end
    end

    enumerator_builder.wrap(enumerator_builder, objects)
  end

  def gate_reference
    resource_for(arguments[0], arguments[1])
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def each_iteration(object, tenant_id, resource_id, _run_id = nil)
    resource = resource_for(tenant_id, resource_id)
    locator_key = resource.locator_key_for(object)

    return track_iteration if dry_run?

    reference = Tenant.switch(resource.tenant) do
      ThingReference.discover!(
        resource: resource,
        locator: resource.locator_for(object),
        locator_key: locator_key,
        kind: resource.kind_for(object),
        title: resource.title_for(object)
      )
    end

    if reference.analyzed_at.nil?
      Tenant.switch(resource.tenant) { AnalyzeThingJob.start!(tenant_id, reference.thing_id) }
    end

    track_iteration
  end

  private

    def release_sync
      return if @resource.nil?

      Tenant.switch(@resource.tenant) { @resource.release_sync! }
    end

    def resource_for(tenant_id, resource_id)
      @resource ||= begin
        tenant = Tenant.find(tenant_id)
        Tenant.switch(tenant) { Resource.find(resource_id) }
      end
    end
end
