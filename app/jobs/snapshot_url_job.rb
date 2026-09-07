class SnapshotUrlJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def self.start!(tenant_id, resource, url)
    Run.start!(kind: "snapshot", resource: resource, selector: { "url" => url }).tap do |run|
      perform_later(tenant_id, resource.id, url, run.id)
    end
  end

  def perform(_tenant_id, resource_id, url, run_id = nil)
    run = Run.find_by(id: run_id)
    resource = Resource.active.find(resource_id)

    run&.running!

    begin
      reference = resource.snapshot!(url)

      run&.progressed!(1)
      run&.finished!

      reference
    rescue StandardError => e
      run&.finished!(error: "#{e.class}: #{e.message}")
      raise
    end
  end
end
