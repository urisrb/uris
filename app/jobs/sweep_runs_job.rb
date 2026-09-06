class SweepRunsJob < ApplicationJob
  queue_as :sync

  def perform
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) do
        Run.past_deadline.find_each(&:expired?)
        delete_settled
      end
    end
  end

  private

    def delete_settled
      retention = Rails.configuration.uris.run_retention
      return if retention.zero?

      Run.where.not(status: Run::OPEN)
         .where(finished_at: ...retention.ago)
         .in_batches(of: 1_000)
         .delete_all
    end
end
