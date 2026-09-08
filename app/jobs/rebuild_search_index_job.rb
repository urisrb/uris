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
          expected += Feed.count

          ReindexFeedsJob.perform_now(tenant.id, target, run.id)
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
          Feed.where(updated_at: started..).find_each { |feed| SearchIndex.index(feed) }
        end
      end
    end
end
