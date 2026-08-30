module Analyzer
  class Calendar < Base
    MAX_EVENTS = 200

    def self.handles?(thing)
      thing.kind == "calendar"
    end

    def analyze
      body = reference.download.read.force_encoding("UTF-8").scrub

      events = step(:events) { parse(body) }

      step(:text) { flatten(events).truncate(MAX_TEXT) }
    end

    private

      # RFC 5545 folds long lines by inserting a break and one space or tab, so
      # unfolding has to happen before anything is split on a colon — otherwise
      # every long SUMMARY is silently truncated at the fold.
      def unfold(body)
        body.gsub(/\r?\n[ \t]/, "")
      end

      def unescape(value)
        value.gsub(/\\([nN,;\\])/) { $1 =~ /[nN]/ ? "\n" : $1 }
      end

      def parse(body)
        events = []
        current = nil

        unfold(body).each_line do |line|
          line = line.strip
          next if line.empty?

          case line
          when "BEGIN:VEVENT" then current = {}
          when "END:VEVENT"
            events << current if current
            current = nil
            break if events.size >= MAX_EVENTS
          else
            assign(current, line) if current
          end
        end

        events
      end

      # DTSTART;TZID=Europe/London:20260830T090000 — the parameters after the
      # semicolon are not part of the name, and keeping them would make every
      # zoned property a field of its own.
      def assign(event, line)
        name, value = line.split(":", 2)
        return if value.nil?

        key = name.split(";").first.to_s.downcase
        return unless %w[summary description location dtstart dtend organizer status uid].include?(key)

        event[key] = unescape(value).truncate(CELL_LIMIT)
      end

      CELL_LIMIT = 1000

      def flatten(events)
        events.map do |event|
          [ event["summary"], event["dtstart"], event["location"], event["description"] ]
            .compact.join(" · ")
        end.join("\n")
      end
  end
end
