class RebuildSearchIndexJob < ApplicationJob
  queue_as :sync
  across_tenants!

  def perform
    return unless SearchIndex.stale?

    started = Time.current
    target = SearchIndex.build!
    expected = 0

    begin
      Tenant.find_each do |tenant|
        Tenant.switch(tenant) do
          run = Run.start!(kind: "reindex", selector: { "index" => target })
          expected += Item.count

          ReindexItemsJob.perform_now(tenant.id, target, run.id)
        end
      end

      SearchIndex.promote!(target, at_least: expected)
    rescue StandardError
      SearchIndex.client.indices.delete(index: target, ignore: 404)
      raise
    end

    catch_up(started)
  end

  private

    def catch_up(started)
      Tenant.find_each do |tenant|
        Tenant.switch(tenant) do
          Item.where(updated_at: started..).find_each { |item| SearchIndex.index(item) }
        end
      end
    end
end
