class ScheduleFeedsJob < ApplicationJob
  queue_as :sync

  def perform
    Tenant.active.find_each do |tenant|
      Tenant.switch(tenant) { Feed.due.find_each(&:run!) }
    end
  end
end
