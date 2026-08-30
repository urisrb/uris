class SyncResourceJob < ApplicationJob
  include JobIteration::Iteration

  queue_as :sync

  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5

  def build_enumerator(tenant_id, resource_id, cursor:)
    resource = resource_for(tenant_id, resource_id)

    objects = Enumerator.new do |yielder|
      resource.each_page(cursor: cursor) do |page, next_cursor|
        page.each { |object| yielder.yield(object, next_cursor) }
      end
    end

    enumerator_builder.wrap(enumerator_builder, objects)
  end

  def each_iteration(object, tenant_id, resource_id)
    resource = resource_for(tenant_id, resource_id)
    locator_key = resource.locator_key_for(object)

    reference = Tenant.switch(resource.tenant) do
      ThingReference.discover!(
        resource: resource,
        locator: resource.locator_for(object),
        locator_key: locator_key,
        kind: Kind.for_filename(locator_key),
        title: File.basename(locator_key)
      )
    end

    AnalyzeThingJob.perform_later(tenant_id, reference.thing_id) if reference.analyzed_at.nil?
  end

  private

    def resource_for(tenant_id, resource_id)
      @resource ||= begin
        tenant = Tenant.find(tenant_id)
        Tenant.switch(tenant) { Resource.find(resource_id) }
      end
    end
end
