module Tool
  def self.all
    [
      Tool::SearchThings,
      Tool::GetThing,
      Tool::AnalyzeThing,
      Tool::ListResources,
      Tool::DescribeResource,
      Tool::CheckResource,
      Tool::CommandResource,
      Tool::SyncResource,
      Tool::ExportThings,
      Tool::ListRuns,
      Tool::CancelRun
    ]
  end
end
