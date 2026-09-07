class Resource
  class Database < Resource
    MAX_TEXT = 100_000

    def self.capabilities
      [ :storage ]
    end

    def self.command_schema
      {
        list: { prefix: "string?" },
        get: { key: "string" },
        put: { key: "string", body: "bytes" }
      }
    end

    PAGE = 500

    def blobs
      ResourceBlob.where(resource_id: id)
    end

    def check!
      blobs.limit(1).count
      true
    end

    def each_page(cursor: nil, prefix: nil)
      loop do
        scope = blobs.order(:id).limit(PAGE)
        scope = scope.where("key LIKE ?", "#{prefix}%") if prefix.present?
        scope = scope.where(id: cursor.to_i..) if cursor.present?
        batch = scope.to_a

        break if batch.empty?

        cursor = (batch.last.id + 1).to_s
        yield batch, cursor

        break if batch.size < PAGE
      end
    end

    def locator_for(blob)
      { "key" => blob.key, "updated_at" => blob.updated_at&.utc&.iso8601 }
    end

    def locator_key_for(blob)
      blob.key
    end

    def version_for(locator)
      locator.to_h["updated_at"].presence
    end

    def download(locator)
      blob = blobs.find_by(key: locator.fetch("key"))
      raise Resource::Failed, "#{key}: no blob at #{locator['key']}" if blob.nil?

      StringIO.new(blob.bytes)
    end

    def upload(name, body)
      content = body.respond_to?(:read) ? body.read : body.to_s

      blob = blobs.find_or_initialize_by(key: name)
      blob.tenant_id ||= tenant_id
      blob.update!(bytes: content)

      { "key" => name }
    end

    def command_list(prefix: nil)
      scope = blobs.order(:key).limit(1000)
      scope = scope.where("key LIKE ?", "#{prefix}%") if prefix.present?
      found = scope.to_a

      {
        "objects" => found.map do |blob|
          { "key" => blob.key, "size" => blob.size, "last_modified" => blob.updated_at }
        end
      }
    end

    def command_get(key:)
      content = download("key" => key).read
      text = content.dup.force_encoding(Encoding::UTF_8)

      if text.valid_encoding?
        { "key" => key, "size" => content.bytesize, "text" => text.truncate(MAX_TEXT) }
      else
        { "key" => key, "size" => content.bytesize, "text" => nil, "note" => "binary" }
      end
    end

    def command_put(key:, body:)
      upload(key, body)
    end
  end
end
