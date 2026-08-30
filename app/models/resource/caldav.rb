class Resource
  class Caldav < Webdav
    CALENDAR = "text/calendar".freeze

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
      "calendar"
    end

    private

      def wanted?(entry)
        entry.content_type.to_s.start_with?(CALENDAR) || entry.path.to_s.downcase.end_with?(".ics")
      end
  end
end
