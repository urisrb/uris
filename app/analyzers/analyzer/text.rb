module Analyzer
  class Text < Base
    def self.handles?(reference)
      %w[text doc].include?(reference.kind)
    end

    def analyze
      step(:text) { reference.download.read.force_encoding("UTF-8").scrub.strip.truncate(MAX_TEXT) }
    end
  end
end
