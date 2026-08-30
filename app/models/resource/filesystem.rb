require "pathname"

class Resource
  class Filesystem < Resource
    class Escaped < Resource::Failed; end

    PAGE = 500
    MAX_TEXT = 100_000

    def self.capabilities
      [ :storage ]
    end

    def self.command_schema
      {
        list: { prefix: "string?", limit: "integer?" },
        get: { key: "string" },
        put: { key: "string", body: "bytes" }
      }
    end

    def self.permitted_roots
      ENV.fetch("THINGS_FILESYSTEM_ROOTS", "").split(":").filter_map do |entry|
        Pathname.new(entry.strip).expand_path if entry.strip.present?
      end
    end

    def root
      @root ||= Pathname.new(details.fetch("root")).expand_path
    end

    def check!
      permitted_root!
      raise Resource::Failed, "#{key}: #{root} is not a readable directory" unless root.directory? && root.readable?

      true
    end

    def each_page(cursor: nil, prefix: nil)
      permitted_root!

      walk(prefix).drop_while { |path| cursor.present? && path <= cursor }
                  .each_slice(PAGE) do |batch|
        yield batch.map { |path| entry(path) }, batch.last
      end
    end

    def locator_for(entry)
      { "path" => entry.path, "size" => entry.size, "modified_at" => entry.modified_at.utc.iso8601 }
    end

    def locator_key_for(entry)
      entry.path
    end

    def download(locator)
      File.open(confine(locator.fetch("path")), "rb")
    rescue Errno::ENOENT
      raise Resource::Failed, "#{key}: nothing at #{locator['path']}"
    rescue SystemCallError => e
      raise Resource::Failed, "#{key}: #{e.message}"
    end

    def upload(name, body)
      target = confine_for_write(name)
      target.dirname.mkpath

      File.open(target, "wb") do |file|
        body.respond_to?(:read) ? IO.copy_stream(body, file) : file.write(body.to_s)
      end

      { "path" => relative(target) }
    rescue SystemCallError => e
      raise Resource::Failed, "#{key}: #{e.message}"
    end

    def command_list(prefix: nil, limit: nil)
      permitted_root!
      count = (limit || 1000).to_i.clamp(1, 5000)

      {
        "objects" => walk(prefix).first(count).map do |path|
          found = entry(path)
          { "key" => found.path, "size" => found.size, "last_modified" => found.modified_at }
        end
      }
    end

    def command_get(key:)
      bytes = download("path" => key).read
      text = bytes.dup.force_encoding(Encoding::UTF_8)

      if text.valid_encoding?
        { "key" => key, "size" => bytes.bytesize, "text" => text.truncate(MAX_TEXT) }
      else
        { "key" => key, "size" => bytes.bytesize, "text" => nil,
          "note" => "binary — sync it into the catalog or export it instead" }
      end
    end

    def command_put(key:, body:)
      upload(key, body)
    end

    private

      Entry = Data.define(:path, :size, :modified_at)

      def entry(path)
        stat = confine(path).lstat

        Entry.new(path: path, size: stat.size, modified_at: stat.mtime)
      end

      def permitted_root!
        allowed = self.class.permitted_roots

        if allowed.empty?
          raise Resource::Failed,
                "#{key}: no filesystem roots are permitted — set THINGS_FILESYSTEM_ROOTS"
        end

        return true if allowed.any? { |permitted| under?(root, permitted) }

        raise Escaped, "#{key}: #{root} is outside every permitted filesystem root"
      end

      def confine(path)
        resolved = resolve(lexical(path))
        escaped!(path) unless under?(resolved, resolve(root))

        resolved
      end

      def confine_for_write(path)
        candidate = lexical(path)
        anchor = resolve(nearest_existing(candidate.dirname))
        escaped!(path) unless under?(anchor, resolve(root))

        candidate
      end

      def lexical(path)
        candidate = (root + path.to_s).cleanpath
        escaped!(path) unless under?(candidate, root.cleanpath)

        candidate
      end

      def nearest_existing(path)
        path = path.parent until path.exist? || path.root?
        path
      end

      def escaped!(path)
        raise Escaped, "#{key}: #{path} resolves outside #{root}"
      end

      def resolve(path)
        Pathname.new(File.realpath(path))
      rescue Errno::ENOENT, Errno::ELOOP, SystemCallError
        raise Resource::Failed, "#{key}: cannot resolve #{relative(path)}"
      end

      def under?(path, ancestor)
        path == ancestor || path.to_s.start_with?("#{ancestor}#{File::SEPARATOR}")
      end

      def relative(path)
        Pathname.new(path).relative_path_from(root).to_s
      rescue ArgumentError
        path.to_s
      end

      def walk(prefix = nil)
        wanted = prefix.presence || details["prefix"].presence

        Enumerator.new do |yielder|
          descend(root, "", yielder)
        end.lazy.select { |path| wanted.nil? || path.start_with?(wanted) }
      end

      def descend(directory, prefix, yielder)
        directory.children.sort_by(&:basename).each do |child|
          next if child.symlink?

          name = prefix.empty? ? child.basename.to_s : File.join(prefix, child.basename.to_s)

          if child.directory?
            descend(child, name, yielder)
          elsif child.file?
            yielder.yield(name)
          end
        end
      rescue SystemCallError
        nil
      end
  end
end
