class Resource
  class MicrosoftGraph < Api
    include Brokered

    API = "https://graph.microsoft.com/v1.0".freeze
    DRIVE = "/me/drive".freeze
    MAX_DOWNLOAD = 512.megabytes
    ROOT = %r{\A/[^:]*:?/?}

    def self.api
      API
    end

    def self.service
      "Microsoft Graph"
    end

    def self.capabilities
      [ :integration ]
    end

    def self.broker_provider
      "microsoft"
    end

    def self.attaching
      {
        label: "OneDrive",
        blurb: "Connected in the browser rather than here — the credential is captured by the " \
               "sign-in server, so no secret is ever typed into uris.",
        names: "A name for it",
        fields: [
          field("folder", "Only under this folder",
                help: "A path within the drive. Left empty, the whole drive is catalogued.",
                placeholder: "Documents/Invoices")
        ]
      }
    end

    def self.command_schema
      {
        list: { folder: "string?", limit: "integer?" },
        get: { id: "string" }
      }
    end

    def folder
      details["folder"].to_s.delete_prefix("/").chomp("/").presence
    end

    def check!
      who = api_get("/me")

      if who["id"].blank?
        raise Resource::Failed, "#{key}: the broker released a token Microsoft would not accept"
      end

      drive = api_get(DRIVE)

      raise Resource::Unusable, "#{key}: #{who['userPrincipalName']} has no drive" if drive["id"].blank?

      true
    end

    # Delta rather than a walk of every folder: one flat enumeration the service pages for us,
    # and a cursor that is the next page's own URL, so a resumed sync asks for exactly what it
    # had not reached.
    def each_page(cursor: nil, prefix: nil)
      held = cursor.presence || "#{DRIVE}/root/delta"

      loop do
        found = api_get(held)
        batch = Array(found["value"]).select { |entry| wanted?(entry, prefix) }
        held = found["@odata.nextLink"]

        yield batch, held if batch.any?

        break if held.blank?
      end
    end

    def locator_for(entry)
      {
        "id" => entry["id"],
        "name" => entry["name"],
        "path" => path_of(entry),
        "mime_type" => entry.dig("file", "mimeType"),
        "size" => entry["size"],
        "etag" => entry["cTag"].presence || entry["eTag"].presence || entry["lastModifiedDateTime"]
      }
    end

    def locator_key_for(entry)
      return entry.to_s unless entry.is_a?(Hash)

      path_of(entry).presence || entry["id"].to_s
    end

    def download(locator)
      wanted = api_redirect("#{DRIVE}/items/#{locator.fetch('id')}/content")

      StringIO.new(pulled(wanted))
    end

    def command_list(folder: nil, limit: nil)
      wanted = folder.presence || self.folder
      path = wanted.present? ? "#{DRIVE}/root:/#{wanted}:/children" : "#{DRIVE}/root/children"
      found = api_get(path, "$top": (limit || PAGE).to_i.clamp(1, PAGE))

      { "folder" => wanted, "files" => Array(found["value"]).map { |entry| described(entry) } }
    end

    def command_get(id:)
      described(api_get("#{DRIVE}/items/#{id}"))
    end

    private

      def wanted?(entry, prefix)
        return false unless entry.is_a?(Hash)
        return false if entry["deleted"].present? || entry["folder"].present?
        return false if entry["file"].blank?

        under = prefix.presence || folder

        under.blank? || locator_key_for(entry).start_with?("#{under.delete_prefix('/').chomp('/')}/")
      end

      def path_of(entry)
        held = entry.dig("parentReference", "path").to_s.sub(ROOT, "")

        [ held.presence, entry["name"] ].compact.join("/").delete_prefix("/")
      end

      def described(entry)
        {
          "id" => entry["id"],
          "name" => entry["name"],
          "path" => path_of(entry),
          "size" => entry["size"],
          "mime_type" => entry.dig("file", "mimeType"),
          "modified_at" => entry["lastModifiedDateTime"],
          "folder" => entry["folder"].present?
        }
      end

      # The content endpoint answers with a redirect to a storage host that refuses the
      # Authorization header it was reached with, so the second leg is deliberately
      # unauthenticated — and, because its host arrives in a response rather than from us,
      # it is checked the way any other address a caller named would be.
      def api_redirect(path)
        uri = endpoint(path, {})

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(Net::HTTP::Get.new(uri, headers))
        end

        return response["location"] if response.is_a?(Net::HTTPRedirection) && response["location"].present?
        raise Api::Gone, "#{key}: #{path} has no content" if response.is_a?(Net::HTTPNotFound)

        raise Resource::Failed, "#{key}: #{self.class.service} answered #{response.code} for content"
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        raise Resource::Failed, "#{key}: #{e.class} reaching #{uri&.host}"
      end

      def pulled(target)
        Download.of(target, max_bytes: MAX_DOWNLOAD).bytes
      rescue Download::Blocked => e
        raise Resource::Unusable, "#{key}: #{e.message}"
      rescue Download::Failed => e
        raise Resource::Failed, "#{key}: #{e.message}"
      end
  end
end
