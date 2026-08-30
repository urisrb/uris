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
      scoped { blobs.limit(1).count }
      true
    end

    # Unlike every other resource, this one's storage is behind the same RLS as
    # the catalog, so each query has to carry the tenant. One short transaction
    # per page rather than one held across the whole enumeration.
    def each_page(cursor: nil, prefix: nil)
      loop do
        batch = scoped do
          scope = blobs.order(:id).limit(PAGE)
          scope = scope.where("key LIKE ?", "#{prefix}%") if prefix.present?
          scope = scope.where(id: cursor.to_i..) if cursor.present?
          scope.to_a
        end

        break if batch.empty?

        cursor = (batch.last.id + 1).to_s
        yield batch, cursor

        break if batch.size < PAGE
      end
    end

    def locator_for(blob)
      { "key" => blob.key }
    end

    def locator_key_for(blob)
      blob.key
    end

    def download(locator)
      blob = scoped { blobs.find_by(key: locator.fetch("key")) }
      raise Resource::Failed, "#{key}: no blob at #{locator['key']}" if blob.nil?

      StringIO.new(blob.bytes)
    end

    def upload(name, body)
      content = body.respond_to?(:read) ? body.read : body.to_s

      scoped do
        blob = blobs.find_or_initialize_by(key: name)
        blob.tenant_id ||= tenant_id
        blob.update!(bytes: content)
      end

      { "key" => name }
    end

    def command_list(prefix: nil)
      found = scoped do
        scope = blobs.order(:key).limit(1000)
        scope = scope.where("key LIKE ?", "#{prefix}%") if prefix.present?
        scope.to_a
      end

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

    private

      def scoped(&block)
        return yield if Current.tenant&.id == tenant_id

        Tenant.switch(tenant, &block)
      end
  end
end
