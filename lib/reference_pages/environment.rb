module ReferencePages
  class Environment < Page
    SOURCES = %w[app config lib bin/docker-entrypoint].freeze
    SKIPPED = %w[lib/reference_pages].freeze
    IGNORED = %w[PATH BUNDLE_GEMFILE CI TEST_ENV_NUMBER].freeze
    READ = /ENV(?:\.fetch\(\s*|\[\s*)"([A-Z][A-Z0-9_]*)"(?:\s*,\s*([^)\n]+?))?\s*[)\]]/
    SHELL = /\$\{?([A-Z][A-Z0-9_]*)/

    def slug = "environment"
    def title = "Environment"
    def description = "Every environment variable uris reads, where it is read, and its default."

    def intro
      <<~TEXT
        Every variable the application reads, found by reading the source for them. A default is shown
        where the code names one inline; a variable with none is unset unless the deployment sets it.
        Rails' own variables are listed only where uris reads them itself.
      TEXT
    end

    def body
      rows = found.except(*IGNORED).sort.map do |name, held|
        defaults = held[:defaults].to_a.uniq.join(" or ")

        [ code(name), defaults.presence ? code(defaults) : "", held[:files].to_a.sort.map { |file| code(file) }.join(" ") ]
      end

      [ table([ "Variable", "Default", "Read in" ], rows) ]
    end

    private

      def found
        held = Hash.new { |hash, key| hash[key] = { files: Set.new, defaults: [] } }

        files.each do |path|
          relative = path.relative_path_from(Rails.root).to_s
          source = path.read

          source.scan(READ).each do |name, default|
            held[name][:files] << relative
            held[name][:defaults] << default.strip if literal?(default)
          end

          next unless relative.start_with?("bin/")

          source.scan(SHELL).flatten.each { |name| held[name][:files] << relative }
        end

        held
      end

      def literal?(default)
        default.present? && default.strip.match?(/\A("[^"#]*"|\d[\d_]*|true|false|nil)\z/)
      end

      def files
        SOURCES.flat_map do |source|
          path = Rails.root.join(source)
          path.directory? ? Pathname.glob(path.join("**/*.{rb,yml,erb,rake}")) : [ path ]
        end.select(&:file?).reject { |path| SKIPPED.any? { |skip| path.to_s.include?(skip) } }
      end
  end
end
