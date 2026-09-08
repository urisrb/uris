namespace :uris do
  desc "Ensure every tenant named by URIS_TENANT or URIS_TENANTS exists"
  task tenants: :environment do
    Tenant.declare!.each { |tenant| puts "#{tenant.subdomain}: #{tenant.name}" }
  end
end
