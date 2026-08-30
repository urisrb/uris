module Analyzer
  class Failed < StandardError; end

  def self.all
    [
      Analyzer::Pdf, Analyzer::Image, Analyzer::Doc, Analyzer::Xlsx,
      Analyzer::Calendar, Analyzer::Pkpass, Analyzer::Email, Analyzer::Feed,
      Analyzer::Data, Analyzer::Text, Analyzer::Fallback
    ]
  end

  def self.for(thing)
    all.find { |analyzer| analyzer.handles?(thing) }.new(thing)
  end
end
