module Tool
  def self.all
    [
      Tool::Search,
      Tool::Feeds,
      Tool::Connect,
      Tool::Resources
    ]
  end
end
