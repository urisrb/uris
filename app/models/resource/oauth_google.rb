class Resource
  class OauthGoogle < Resource
    include Brokered

    API = "https://www.googleapis.com/drive/v3".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20
    MAX_TEXT = 100_000
    PAGE = 100
    FIELDS = "id,name,mimeType,size,md5Checksum,modifiedTime,parents".freeze

    def self.capabilities
      [ :integration ]
    end

    def self.broker_provider
      "google"
    end

    def self.command_schema
      {
        list: { query: "string?", folder: "string?", page_token: "string?", limit: "integer?" },
        get: { id: "string" }
      }
    end

    def check!
      about = api_get("/about", fields: "user")

      raise Resource::Failed, "#{key}: the broker released a token Drive would not accept" if about["user"].blank?

      true
    end

    def command_list(query: nil, folder: nil, page_token: nil, limit: nil)
      page = api_get(
        "/files",
        q: drive_query(query, folder),
        pageSize: [ limit&.to_i || PAGE, PAGE ].min,
        pageToken: page_token.presence,
        fields: "nextPageToken,files(#{FIELDS})",
        supportsAllDrives: true,
        includeItemsFromAllDrives: true
      )

      {
        "files" => Array(page["files"]).map { |file| describe(file) },
        "page_token" => page["nextPageToken"]
      }
    end

    def command_get(id:)
      file = api_get("/files/#{CGI.escape(id)}", fields: FIELDS, supportsAllDrives: true)

      describe(file).merge(text_for(file))
    end

    def locator_for(file)
      {
        "id" => file["id"],
        "name" => file["name"],
        "mime_type" => file["mimeType"],
        "etag" => file["md5Checksum"].presence || file["modifiedTime"]
      }
    end

    def locator_key_for(file)
      file.is_a?(Hash) ? file["name"].to_s : file.to_s
    end

    def download(locator)
      StringIO.new(api_download(locator.fetch("id")))
    end

    private

      def describe(file)
        {
          "id" => file["id"],
          "name" => file["name"],
          "mime_type" => file["mimeType"],
          "size" => file["size"]&.to_i,
          "modified_at" => file["modifiedTime"]
        }
      end

      def text_for(file)
        return { "text" => nil, "note" => "a folder has no content" } if folder?(file)
        return { "text" => nil, "note" => "an editor document must be exported, not downloaded" } if native?(file)

        bytes = api_download(file["id"])
        text = bytes.dup.force_encoding(Encoding::UTF_8)

        return { "text" => text.truncate(MAX_TEXT) } if text.valid_encoding?

        { "text" => nil, "note" => "binary — export it or sync it into the catalog instead" }
      end

      def folder?(file)
        file["mimeType"] == "application/vnd.google-apps.folder"
      end

      def native?(file)
        file["mimeType"].to_s.start_with?("application/vnd.google-apps.")
      end

      def drive_query(query, folder)
        clauses = [ "trashed = false" ]
        clauses << "name contains '#{query.gsub("'", "\\\\'")}'" if query.present?
        clauses << "'#{folder.gsub("'", "\\\\'")}' in parents" if folder.present?
        clauses << details["query"] if details["query"].present?

        clauses.join(" and ")
      end

      def api_get(path, **query)
        request(URI.parse("#{API}#{path}?#{URI.encode_www_form(query.compact)}")) do |body|
          JSON.parse(body)
        end
      end

      def api_download(id)
        uri = URI.parse("#{API}/files/#{CGI.escape(id)}?alt=media&supportsAllDrives=true")

        request(uri) { |body| body }
      end

      def request(uri, retried: false)
        response = Net::HTTP.start(
          uri.hostname, uri.port,
          use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT
        ) { |http| http.request(Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{upstream_token}")) }

        if response.is_a?(Net::HTTPUnauthorized) && !retried
          forget_upstream_token
          return request(uri, retried: true)
        end

        raise Resource::Failed, "#{key}: #{drive_error(response)}" unless response.is_a?(Net::HTTPSuccess)

        yield response.body
      rescue JSON::ParserError
        raise Resource::Failed, "#{key}: Drive returned something that is not JSON"
      rescue Net::HTTPBadResponse, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError,
             OpenSSL::SSL::SSLError => e
        raise Resource::Failed, "#{key}: Drive did not answer (#{e.class})"
      end

      def drive_error(response)
        parsed = JSON.parse(response.body.to_s[0, 4096])
        parsed.dig("error", "message").presence || "Drive answered #{response.code}"
      rescue JSON::ParserError
        "Drive answered #{response.code}"
      end
  end
end
