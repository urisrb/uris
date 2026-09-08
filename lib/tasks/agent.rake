namespace :agent do
  desc "Run one prompt through the agent against a tenant: rake agent:ask[demo,'find invoices']"
  task :ask, [ :subdomain, :prompt ] => :environment do |_task, args|
    subdomain = args[:subdomain].presence || "demo"
    prompt = args[:prompt].presence || "Find invoice PDFs, then tell me about the first one."

    tenant = Tenant.find_by(subdomain: subdomain) or
      abort "no tenant #{subdomain.inspect} — try one of: #{Tenant.pluck(:subdomain).join(', ')}"

    Tenant.switch(tenant) do
      claims = Masks::Client::Claims.new(
        "sub" => "rake",
        "scope" => Grant::SIGN_IN.join(" "),
        "tenant" => { "subdomain" => tenant.subdomain }
      )
      grant = Grant.new(tenant: tenant, claims: claims)
      Current.grant = grant

      agent = Agent.new(grant: grant)
      puts "  #{agent.inference_key} · offering #{agent.offered_names.join(', ')}"
      puts

      answered = agent.call(prompt)

      puts
      puts "  #{answered.turns} turn(s), #{answered.reason} — #{answered.said}"
    end
  end
end
