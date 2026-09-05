class SweepRunsJob < ApplicationJob
  queue_as :sync

  def perform
    retention = Rails.configuration.uris.run_retention
    return if retention.zero?

    cutoff = retention.ago

    Tenant.find_each do |tenant|
      Tenant.switch(tenant) do
        Run.where.not(status: Run::OPEN)
           .where(finished_at: ...cutoff)
           .in_batches(of: 1_000)
           .delete_all
      end
    end
  end
end
