namespace :inference do
  desc "Summarize the reference corpus against the live model, and report what came back"
  task corpus: :environment do
    corpus = Rails.root.join("test/fixtures/corpus")
    abort "no corpus at #{corpus} — see its README" unless corpus.directory?

    subdomain = ENV.fetch("TENANT", "demo")
    tenant = Tenant.find_by(subdomain: subdomain) || abort("no tenant #{subdomain}")

    Tenant.switch(tenant) do
      inference = Resource.default_inference
      abort "#{subdomain} has no default inference resource — run db:seed with OLLAMA_URL set" if inference.nil?

      unless inference.check
        abort "#{inference.key} is not answering: #{inference.check_error}"
      end

      storage = Resource.default_storage!
      only = ENV["ONLY"]

      files = corpus.glob("*/*").reject(&:directory?).sort
      files = files.select { |file| file.to_s.include?(only) } if only.present?

      puts format("%-28s %-9s %8s  %s", "file", "kind", "seconds", "summary")
      puts "-" * 110

      files.each do |file|
        key = "corpus/#{file.parent.basename}/#{file.basename}"
        storage.upload(key, file.binread)

        reference = Reference.discover!(
          resource: storage, locator: { "key" => key }, locator_key: key,
          kind: Kind.for_filename(key), title: file.basename.to_s
        )

        item = reference.item
        started = Time.current

        begin
          Analyzer.for(item).run
        rescue StandardError => e
          puts format("%-28s %-9s %8s  %s", file.basename, item.kind, "-", "#{e.class}: #{e.message.truncate(60)}")
          next
        end

        elapsed = (Time.current - started).round(1)
        step = reference.reload.analysis.dig("steps", "summary")

        line =
          if step.nil? then "(no summary — nothing extracted, or below the minimum)"
          elsif step["error"] then "ERROR #{step['error']['message'].to_s.truncate(60)}"
          else step.dig("result", "summary").to_s.truncate(64)
          end

        puts format("%-28s %-9s %8s  %s", file.basename.to_s.truncate(28), item.kind, elapsed, line)
      end

      puts
      puts "prompts: #{Prompt.count}, failed attempts: #{Prompt.where("response ? 'error'").count}"
    end
  end
end
