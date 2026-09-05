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

    # An analyzer that finds things inside its bytes says so, and those things
    # are catalogued before it reads anything else. Extraction is idempotent
    # and keyed, so a re-analysis finds the children it made last time rather
    # than a second copy of them.
    def run
      extract_children! if thing.depth < Thing::DEPTH

      return thing unless thing.children_ready?

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

      thing.reload.announce_analyzed!
      thing
    end

    def analyze
    end

    def has_children?
      false
    end

    def children_of(_reference)
      []
    end

    def child_storage
      Resource::Database.find_or_create_by!(key: "children") do |resource|
        resource.name = "Extracted children"
        resource.details = {}
      end
    end

    private

      def extract_children!
        return unless has_children?

        made = thing.references.flat_map { |reference| catalogue_children(reference) }

        made.each { |child| AnalyzeThingJob.perform_later(thing.tenant_id, child.id) }
        thing.children.reset
      end

      def catalogue_children(reference)
        @reference = reference
        storage = child_storage

        children_of(reference).filter_map.with_index do |child, index|
          key = "#{reference.id}/#{index}/#{child.fetch(:filename)}"
          next if ThingReference.exists?(resource: storage, locator_key: key)

          record_child(storage, key, child)
        end
      rescue Analyzer::Failed
        []
      end

      def record_child(storage, key, child)
        storage.upload(key, child.fetch(:body))

        held = Thing.create!(
          kind: Kind.for_filename(child.fetch(:filename)) || "file",
          title: child.fetch(:filename),
          parent: thing
        )

        ThingReference.record!(
          thing: held, resource: storage, locator_key: key,
          locator: { "key" => key }
        )

        held
      end

    public

    def step(name, force: false, after: nil)
      name = name.to_s
      stored = reference.analysis.dig("steps", name) || {}

      if stored.key?("result") && !force && fresh?(stored, after) && !superseded?(stored)
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
        analysis["steps"] = (analysis["steps"] || {}).merge(name.to_s => storable(entry))

        Tenant.switch(reference.tenant) { reference.update!(analysis: analysis) }
      end

      def storable(value)
        case value
        when String
          value.dup.force_encoding(Encoding::UTF_8).scrub.delete("\u0000")
        when Array
          value.map { |item| storable(item) }
        when Hash
          value.to_h { |key, item| [ storable(key), storable(item) ] }
        else
          value
        end
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

      def superseded?(stored)
        return false if reference.changed_at.nil?

        Time.iso8601(stored["finished_at"]) < reference.changed_at
      rescue ArgumentError, TypeError
        true
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
