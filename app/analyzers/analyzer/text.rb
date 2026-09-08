module Analyzer
  class Text < Base
    def self.handles?(feed)
      MimeType.text?(feed.mime)
    end

    def analyze
      step(:text) { reference.download.read.force_encoding("UTF-8").scrub.strip.truncate(MAX_TEXT) }
    end
  end
end
