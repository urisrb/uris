class SyncResourceJob < ApplicationJob
  include JobIteration::Iteration

  queue_as :sync

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

    thing = Tenant.switch(resource.tenant) do
      Thing.upsert_reference!(
        resource: resource,
        locator: resource.locator_for(object),
        locator_key: resource.locator_key_for(object),
        kind: Kind.for_filename(resource.locator_key_for(object)),
        title: File.basename(resource.locator_key_for(object))
      )
    end

    thing.analyze! if thing.analyzed_at.nil?
  end

  private

    def resource_for(tenant_id, resource_id)
      @resource ||= begin
        tenant = Tenant.find(tenant_id)
        Tenant.switch(tenant) { Resource.find(resource_id) }
      end
    end
end
