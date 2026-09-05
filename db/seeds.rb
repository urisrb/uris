TENANTS = [
  { subdomain: "demo",  name: "Demo things" },
  { subdomain: "acme",  name: "Acme" }
]

TENANTS.each do |attrs|
  tenant = Tenant.find_or_create_by!(subdomain: attrs[:subdomain]) { |t| t.name = attrs[:name] }

  Tenant.switch(tenant) do
    Resource::Database.find_or_create_by!(key: "database") do |resource|
      resource.name = "Default storage"
    end.make_default_storage!

    storage = Resource::S3.find_or_initialize_by(key: "things-#{tenant.subdomain}")
    storage.assign_attributes(
      name: "Object storage",
      details: {
        "endpoint" => ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
        "region" => ENV.fetch("S3_REGION", "us-east-1")
      },
      credentials: {
        "access_key_id" => ENV.fetch("S3_ACCESS_KEY_ID", "things"),
        "secret_access_key" => ENV.fetch("S3_SECRET_ACCESS_KEY", "thingsthings")
      }
    )
    storage.save!

    begin
      storage.client.create_bucket(bucket: storage.bucket)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou
      nil
    rescue Seahorse::Client::NetworkingError => e
      warn "  storage unreachable (#{e.class}) — is docker compose running?"
    end

    if (endpoint = ENV["OLLAMA_URL"]).present?
      brain = Resource::OpenaiCompatible.find_or_initialize_by(key: "ollama")
      brain.assign_attributes(
        name: "Local models",
        details: {
          "base_url" => endpoint,
          "models" => {
            "fast" => ENV.fetch("OLLAMA_FAST_MODEL", "gemma3:4b"),
            "smart" => ENV.fetch("OLLAMA_SMART_MODEL", "llama3.1:8b"),
            "vision" => ENV.fetch("OLLAMA_VISION_MODEL", "gemma3:4b")
          }
        }
      )
      brain.save!

      held = Resource.default_inference
      brain.make_default_inference! if held.nil? || held == brain

      unless brain.check
        warn "  ollama unreachable at #{endpoint} — #{brain.check_error}"
        warn "  summaries will be skipped until it answers"
      end
    end

    puts "seeded #{tenant.subdomain}: #{Resource.active.count} resource(s)"
  end
end
