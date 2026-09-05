namespace :search do
  def tenants
    named = ENV["TENANT"].presence
    return Tenant.where(subdomain: named) if named

    Tenant.all
  end

  def start_run(tenant, index)
    Tenant.switch(tenant) { Run.start!(kind: "reindex", selector: { "index" => index }) }
  end

  desc "Re-index every item into the live index, resumably, one run per tenant"
  task reindex: :environment do
    tenants.find_each do |tenant|
      run = start_run(tenant, SearchIndex.alias_name)
      ReindexItemsJob.perform_later(tenant.id, nil, run.id)

      puts "#{tenant.subdomain}: run #{run.id}"
    end
  end

  desc "Build a new index with today's mapping, fill it, and promote it in one call"
  task rebuild: :environment do
    target = SearchIndex.build!
    expected = 0

    puts "building #{target}"

    tenants.find_each do |tenant|
      run = start_run(tenant, target)
      ReindexItemsJob.perform_now(tenant.id, target, run.id)

      held = Tenant.switch(tenant) { Item.count }
      expected += held

      puts "#{tenant.subdomain}: #{held} items, run #{run.id}"
    end

    begin
      SearchIndex.promote!(target, at_least: expected)
    rescue StandardError
      warn "#{target} is still there — read search:indices, then promote or drop it"
      raise
    end

    puts "promoted #{target}"
    puts "anything written while that ran is not in it yet — run search:reindex to catch up"
  end

  desc "List the indices behind the aliases, so an abandoned rebuild is visible"
  task indices: :environment do
    live = SearchIndex.live_index

    SearchIndex.client.indices.get(index: "#{SearchIndex.alias_name}*").keys.sort.each do |name|
      puts "#{name == live ? '*' : ' '} #{name}"
    end
  end

  desc "Delete an index a rebuild abandoned — never the one being queried"
  task :drop, [ :name ] => :environment do |_task, args|
    name = args[:name].to_s

    abort "search:drop[name] — which index?" if name.empty?
    abort "#{name} is the one being queried" if name == SearchIndex.live_index

    SearchIndex.client.indices.delete(index: name, ignore: 404)
    puts "dropped #{name}"
  end
end
