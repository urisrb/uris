module Analyzer
  class Text < Base
    def self.handles?(thing)
      %w[text doc].include?(thing.kind)
    end

    def analyze
      step(:text) { thing.download.read.force_encoding("UTF-8").scrub.strip.truncate(MAX_TEXT) }
    end
  end
end
