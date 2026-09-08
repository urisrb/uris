namespace :uris do
  desc "Reconcile every resource config/resources.yml declares, in every tenant"
  task resources: :environment do
    Tenant.find_each do |tenant|
      Tenant.switch(tenant) do
        Resource.declare!.each { |resource| puts "#{tenant.subdomain}: #{resource.key}" }
      end
    end
  end
end
