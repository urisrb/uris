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

      puts format("%-28s %-24s %8s  %s", "file", "mime", "seconds", "summary")
      puts "-" * 110

      files.each do |file|
        key = "corpus/#{file.parent.basename}/#{file.basename}"
        storage.upload(key, file.binread)

        reference = Reference.discover!(
          resource: storage, locator: { "key" => key }, locator_key: key,
          mime: MimeType.for_filename(key), title: file.basename.to_s
        )

        feed = reference.feed
        analysis = Analysis.open!(feed: feed, cause: "manual", reference: reference)
        started = Time.current

        begin
          Analyzer.for(feed, analysis: analysis).run
        rescue StandardError => e
          puts format("%-28s %-24s %8s  %s", file.basename, reference.mime, "-", "#{e.class}: #{e.message.truncate(60)}")
          next
        end

        elapsed = (Time.current - started).round(1)
        step = analysis.reload.step("summary").presence

        line =
          if step.nil? then "(no summary — nothing extracted, or below the minimum)"
          elsif step["error"] then "ERROR #{step['error']['message'].to_s.truncate(60)}"
          else step.dig("result", "summary").to_s.truncate(64)
          end

        puts format("%-28s %-24s %8s  %s", file.basename.to_s.truncate(28), reference.mime, elapsed, line)
      end

      puts
      puts "turns: #{Analysis.sum("jsonb_array_length(turns)")}"
    end
  end
end
