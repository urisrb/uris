class ExportThingsJob < ApplicationJob
  include JobIteration::Iteration
  include TrackedRun

  queue_as :export

  gated_as "export"

  retry_on Resource::Failed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.fail_run(error)
  end

  def run_id
    arguments[3]
  end

  def build_enumerator(tenant_id, destination_id, selector, _run_id = nil, cursor:)
    ids = Tenant.switch(Tenant.find(tenant_id)) do
      Resource.find(destination_id).storage!
      select(selector).pluck(:id)
    end

    enumerator_builder.build_array_enumerator(ids, cursor: cursor)
  end

  def each_iteration(thing_id, tenant_id, destination_id, _selector, _run_id = nil)
    tenant = Tenant.find(tenant_id)

    Tenant.switch(tenant) do
      destination = Resource.find(destination_id)
      thing = Thing.find_by(id: thing_id)
      source = thing&.source_for(destination)

      next if source.nil?

      copy = thing.copy_at(destination)

      next if copy && !copy.stale_against?(source)

      path = copy&.locator_key || source.path
      locator = destination.upload(path, source.download)

      ThingReference.record!(
        thing: thing, resource: destination, locator: locator, locator_key: path,
        source_version: source.version
      )
    end

    track_iteration
  end

  private

    def select(selector)
      Thing.referenced.matching(selector)
    end
end
