module Markup
  ENTITIES = {
    "nbsp" => " ", "amp" => "&", "lt" => "<", "gt" => ">",
    "quot" => '"', "apos" => "'", "#39" => "'"
  }.freeze

  def self.strip(html)
    html.to_s
        .gsub(%r{<(script|style)[^>]*>.*?</\1>}mi, " ")
        .gsub(/<[^>]+>/, " ")
        .gsub(/&(#?\w+);/i) { ENTITIES.fetch(Regexp.last_match(1).downcase, " ") }
        .squeeze(" ")
        .strip
  end
end
