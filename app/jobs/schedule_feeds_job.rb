class ScheduleFeedsJob < ApplicationJob
  queue_as :sync
  across_tenants!

  def perform
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) { Schedule.due.find_each(&:run!) }
    end
  end
end
