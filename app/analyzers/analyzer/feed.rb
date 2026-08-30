module Analyzer
  class Feed < Base
    def self.handles?(thing)
      thing.kind == "feed"
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

        [ reference.thing.title, strip_tags(content) ].compact_blank.join("\n\n").strip
      end

      def strip_tags(html)
        html.gsub(%r{<(script|style)[^>]*>.*?</\1>}mi, " ")
            .gsub(/<[^>]+>/, " ")
            .gsub(/&nbsp;/i, " ")
            .gsub(/&amp;/i, "&")
            .squeeze(" ")
            .strip
      end
  end
end
