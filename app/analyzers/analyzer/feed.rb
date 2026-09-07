module Analyzer
  class Feed < Base
    def self.handles?(item)
      item.kind == "feed"
    end

    def analyze
      step(:entry) { entry_of(reference) }
      step(:text) { body_of(reference).truncate(MAX_TEXT) }
    end

    private

      def entry_of(reference)
        reference.locator.slice("link", "published_at").compact
      end

      def body_of(reference)
        content = reference.download.read.force_encoding("UTF-8").scrub

        [ reference.item.title, Markup.strip(content) ].compact_blank.join("\n\n").strip
      end
  end
end
