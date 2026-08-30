class ExportThingsJob < ApplicationJob
  include JobIteration::Iteration

  queue_as :export

  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5

  def build_enumerator(tenant_id, destination_id, selector, cursor:)
    ids = Tenant.switch(Tenant.find(tenant_id)) do
      Resource.find(destination_id).storage!
      select(selector).pluck(:id)
    end

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(thing_id, tenant_id, destination_id, _selector)
    tenant = Tenant.find(tenant_id)

    Tenant.switch(tenant) do
      destination = Resource.find(destination_id)
      thing = Thing.find(thing_id)

      next if thing.reference.nil? || thing.referenced_by?(destination)

      destination.upload(thing.export_path, thing.download)
    end
  end

  private

    def select(selector)
      Thing.referenced.matching(selector)
    end
end
