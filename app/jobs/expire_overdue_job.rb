class ExpireOverdueJob < ApplicationJob
  queue_as :sync
  across_tenants!

  def perform
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) do
        Run.past_deadline.find_each(&:expired?)
        Analysis.past_deadline.find_each(&:expired?)
      end
    end
  end
end
