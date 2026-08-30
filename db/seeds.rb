# Two tenants, always. A single-tenant seed is how single-tenant assumptions
# get in: a singleton key, a global config, a scope someone forgot. With two
# here from the first run, the isolation test has something to assert against
# before there is anything worth isolating.

TENANTS = [
  { subdomain: "jons",  name: "Jon's things" },
  { subdomain: "acme",  name: "Acme" }
]

TENANTS.each do |attrs|
  tenant = Tenant.find_or_create_by!(subdomain: attrs[:subdomain]) do |t|
    t.name = attrs[:name]
  end

  Tenant.switch(tenant) do
    next if Thing.exists?

    Thing.create!(kind: "text",  title: "#{tenant.name} — a note")
    Thing.create!(kind: "pdf",   title: "#{tenant.name} — a document")
    Thing.create!(kind: "image", title: "#{tenant.name} — a photo")
  end

  puts "seeded #{tenant.subdomain}.#{ENV.fetch('THINGS_HOST_SUFFIX', 'things.test')}"
end
