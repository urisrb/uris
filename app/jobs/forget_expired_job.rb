class ForgetExpiredJob < ApplicationJob
  queue_as :sync
  across_tenants!

  def perform
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) { forget_expired }
    end
  end

  private

    def forget_expired
      Feed.expired.find_each do |feed|
        title = feed.title || feed.key
        feed.destroy!

        AuditEvent.record(
          channel: "job", action: "forget_expired_feed", status: "ok",
          grant: nil, context: { remote_ip: nil, request_id: nil },
          told: "forgot #{title}, whose time ran out",
          arguments: { "title" => title }
        )
      end
    end
end
