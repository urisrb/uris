module Analyzer
  class Failed < StandardError; end

  PROMPTS_CHANGED_AT = Time.utc(2026, 9, 5).freeze

  def self.all
    [
      Analyzer::Pdf, Analyzer::Image, Analyzer::Page, Analyzer::Doc, Analyzer::Xlsx,
      Analyzer::Calendar, Analyzer::Pkpass, Analyzer::Email, Analyzer::Feed, Analyzer::Contact,
      Analyzer::Data, Analyzer::Text, Analyzer::Fallback
    ]
  end

  def self.for(item, run: nil)
    all.find { |analyzer| analyzer.handles?(item) }.new(item, run: run)
  end
end
