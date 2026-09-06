class FetchUrlJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def self.start!(tenant_id, url)
    Run.start!(kind: "fetch", selector: { "url" => url }).tap do |run|
      perform_later(tenant_id, url, run.id)
    end
  end

  def perform(tenant_id, url, run_id = nil)
    Tenant.switch(Tenant.find(tenant_id)) do
      run = Run.find_by(id: run_id)

      run&.running!

      begin
        got = Download.of(url)
        landed = Intake.write!(
          path: Intake.filed("downloads", got.filename),
          body: got.bytes,
          title: got.filename,
          source: got.final_url
        )

        run&.progressed!(1)
        run&.finished!

        landed
      rescue StandardError => e
        run&.finished!(error: "#{e.class}: #{e.message}")
        raise
      end
    end
  end
end
