require "open3"

module Analyzer
  class Base
    MAX_TEXT = 200_000

    attr_reader :thing, :reference

    def initialize(thing)
      @thing = thing
    end

    def self.handles?(_thing)
      false
    end

    def self.kind
      name.demodulize.underscore
    end

    def run
      thing.references.each do |reference|
        @reference = reference

        begin
          analyze
        rescue Analyzer::Failed
          nil
        ensure
          stamp_analyzed!
        end
      end

      thing.announce_analyzed!
      thing
    end

    def analyze
    end

    def step(name, force: false, after: nil)
      name = name.to_s
      stored = reference.analysis.dig("steps", name) || {}

      if stored.key?("result") && !force && fresh?(stored, after)
        return stored["result"]
      end

      started_at = Time.current

      begin
        result = yield
        write_step!(name, {
          "started_at" => started_at.iso8601(3),
          "finished_at" => Time.current.iso8601(3),
          "result" => result
        })
        result
      rescue StandardError => e
        write_step!(name, {
          "started_at" => started_at.iso8601(3),
          "finished_at" => Time.current.iso8601(3),
          "error" => { "class" => e.class.name, "message" => e.message.truncate(500) }
        })
        raise
      end
    end

    def step_result(name)
      reference.analysis.dig("steps", name.to_s, "result")
    end

    private

      # One short transaction per step, rather than one held across an OCR run.
      def write_step!(name, entry)
        analysis = reference.analysis.deep_dup
        analysis["steps"] = (analysis["steps"] || {}).merge(name.to_s => entry)

        Tenant.switch(reference.tenant) { reference.update!(analysis: analysis) }
      end

      def stamp_analyzed!
        Tenant.switch(reference.tenant) { reference.update!(analyzed_at: Time.current) }
      end

      def fresh?(stored, after)
        return true if after.nil?

        cutoff = after.is_a?(Time) ? after : Time.parse(after.to_s)
        Time.iso8601(stored["finished_at"]) >= cutoff
      rescue ArgumentError, TypeError
        false
      end

      def with_tempfile
        Tempfile.create([ "thing", File.extname(reference.locator_key.to_s) ], binmode: true) do |file|
          IO.copy_stream(reference.download, file)
          file.flush
          yield file.path
        end
      end

      def run_command(*args)
        stdout, stderr, status = Open3.capture3(*args)
        raise Analyzer::Failed, "#{args.first} failed: #{stderr.truncate(200)}" unless status.success?

        stdout
      end
  end
end
