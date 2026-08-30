module Analyzer
  def self.all
    [ Analyzer::Pdf, Analyzer::Image, Analyzer::Data, Analyzer::Text, Analyzer::Fallback ]
  end

  def self.for(thing)
    all.find { |analyzer| analyzer.handles?(thing) }.new(thing)
  end
end
