class Resource
  class Caldav < Webdav
    CALENDAR = "text/calendar".freeze

    def self.attaching
      super.merge(
        label: "Calendars",
        blurb: "A CalDAV collection. Only the events in it are catalogued.",
        fields: super[:fields].map { |held|
          held[:name] == "url" ? held.merge(placeholder: "https://cloud.example.com/remote.php/dav/calendars/you/") : held
        }
      )
    end

    def self.command_schema
      {
        list: { prefix: "string?", limit: "integer?" },
        get: { key: "string" }
      }
    end

    def mime_for(_entry)
      "text/calendar"
    end

    private

      def wanted?(entry)
        entry.content_type.to_s.start_with?(CALENDAR) || entry.path.to_s.downcase.end_with?(".ics")
      end
  end
end
