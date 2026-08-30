module Analyzer
  class Fallback < Base
    def self.handles?(_thing)
      true
    end

    def analyze
      step(:size) { { "bytes" => thing.download.size } }
    end
  end
end
