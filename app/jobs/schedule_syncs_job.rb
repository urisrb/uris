class ScheduleSyncsJob < ApplicationJob
  queue_as :sync

  def perform
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) do
        Resource.due_for_sync.find_each do |resource|
          resource.sync! if resource.syncable?
        end
      end
    end
  end
end
