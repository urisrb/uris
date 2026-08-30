class Resource
  class Carddav < Webdav
    VCARD = "text/vcard".freeze
    LEGACY = "text/x-vcard".freeze

    def self.capabilities
      []
    end

    def self.command_schema
      {
        list: { prefix: "string?", limit: "integer?" },
        get: { key: "string" }
      }
    end

    def kind_for(_entry)
      "contact"
    end

    private

      def wanted?(entry)
        type = entry.content_type.to_s

        type.start_with?(VCARD, LEGACY) || entry.path.to_s.downcase.end_with?(".vcf")
      end
  end
end
