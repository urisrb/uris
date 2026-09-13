class ScheduleChecksJob < ApplicationJob
  queue_as :sync
  across_tenants!

  def perform
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) do
        Resource.due_for_check.find_each { |resource| CheckResourceJob.perform_later(resource.id) }
      end
    end
  end
end
