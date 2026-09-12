wanted = ENV.fetch("CORPUS_TENANT")
tenant = Tenant.find_by(subdomain: wanted)

abort "no tenant '#{wanted}' — try one of: #{Tenant.pluck(:subdomain).join(', ')}" if tenant.nil?

root = Rails.root.join("test/fixtures/corpus")
group = ENV["CORPUS_GROUP"].to_s.strip
paths = Pathname.glob(root.join(group.presence || "*", "*")).reject(&:directory?).sort

abort "nothing to load under #{root}/#{group}" if paths.empty?

keys = nil
started = Time.current

Tenant.switch(tenant) do
  storage = Resource.default_storage!

  stale = Feed.joins(:references)
              .where("feed_references.locator_key LIKE 'corpus/%'").distinct.pluck(:id)

  if stale.any?
    puts "clearing #{stale.length} feed(s) a previous run left behind"
    Feed.where(id: stale).destroy_all
  end

  keys = paths.map do |path|
    key = "corpus/#{path.dirname.basename}/#{path.basename}"
    storage.upload(key, path.binread)
    key
  end

  puts "#{keys.length} file(s) into #{storage.key}, analyzing as #{tenant.subdomain}"

  SyncResourceJob.perform_now(tenant.id, storage.id)
end

described = {}
deadline = started + ENV.fetch("CORPUS_TIMEOUT", "1800").to_i

report = lambda do |reference|
  steps = reference.feed.analysis&.steps || {}
  summary = steps.dig("summary", "result") || {}
  failures = steps.select { |_name, step| step.key?("error") }

  puts "\n#{reference.locator_key} [#{reference.mime}]"

  if summary["summary"].present?
    puts "  #{summary['summary']}"
    puts "  keywords: #{Array(summary['keywords']).join(', ')}" if summary["keywords"].present?
  elsif steps.key?("summary")
    puts "  no description: #{steps.dig('summary', 'error', 'message')}"
  else
    puts "  no summary step — nothing served the role, or there was nothing to ask about"
  end

  failures.except("summary").each do |name, step|
    puts "  #{name} failed: #{step.dig('error', 'message').to_s.split("\n").first}"
  end
end

loop do
  pending = []

  Tenant.switch(tenant) do
    Reference.where(locator_key: keys).order(:locator_key).each do |reference|
      settling = reference.analyzed_at.nil? || reference.feed.analyses.open.exists?
      next pending << reference.locator_key if settling
      next if described.key?(reference.locator_key)

      described[reference.locator_key] = true
      report.call(reference)
    end
  end

  break if pending.empty?

  if Time.current > deadline
    puts "\nstill analyzing when the timeout ran out: #{pending.join(', ')}"
    break
  end

  sleep 2
end

asked = Tenant.switch(tenant) do
  Analysis.where(created_at: started..).sum("jsonb_array_length(turns)")
end

puts "\n#{described.length}/#{keys.length} analyzed in #{(Time.current - started).round}s, " \
     "#{asked} call(s) to a model"
