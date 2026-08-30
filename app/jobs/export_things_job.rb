class ExportThingsJob < ApplicationJob
  include JobIteration::Iteration

  queue_as :export

  def build_enumerator(tenant_id, destination_id, selector, cursor:)
    ids = Tenant.switch(Tenant.find(tenant_id)) { select(selector).pluck(:id) }

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(thing_id, tenant_id, destination_id, _selector)
    tenant = Tenant.find(tenant_id)

    Tenant.switch(tenant) do
      destination = Resource.find(destination_id)
      thing = Thing.find(thing_id)

      next if thing.resource.nil? || thing.resource == destination

      destination.upload(thing.export_path, thing.download)
    end
  end

  private

    def select(selector)
      scope = Thing.where.not(resource_id: nil)
      scope = scope.where(kind: selector["kind"]) if selector["kind"].present?
      scope = scope.where(resource_id: selector["resource_id"]) if selector["resource_id"].present?
      scope = scope.where(id: Thing.search(selector["query"]).ids) if selector["query"].present?
      scope
    end
end
