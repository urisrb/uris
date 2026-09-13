class Resource
  class Carddav < Webdav
    VCARD = "text/vcard".freeze
    LEGACY = "text/x-vcard".freeze

    def self.attaching
      super.merge(
        label: "Contacts",
        blurb: "A CardDAV collection. Only the cards in it are catalogued.",
        fields: super[:fields].map { |held|
          held[:name] == "url" ? held.merge(placeholder: "https://cloud.example.com/remote.php/dav/addressbooks/users/you/") : held
        }
      )
    end

    def self.command_schema
      {
        list: { prefix: "string?", limit: "integer?" },
        get: { key: "string" },
        keep: { key: "string" }
      }
    end

    def mime_for(_entry)
      "text/vcard"
    end

    private

      def wanted?(entry)
        type = entry.content_type.to_s

        type.start_with?(VCARD, LEGACY) || entry.path.to_s.downcase.end_with?(".vcf")
      end
  end
end
