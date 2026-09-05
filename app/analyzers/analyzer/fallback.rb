module Analyzer
  class Fallback < Base
    def self.handles?(_item)
      true
    end

    def analyze
      step(:size) { { "bytes" => reference.download.size } }
    end
  end
end
