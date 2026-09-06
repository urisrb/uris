module Tool
  def self.all
    [
      Tool::SearchItems,
      Tool::SearchWeb,
      Tool::GetItem,
      Tool::AnalyzeItem,
      Tool::ListResources,
      Tool::DescribeResource,
      Tool::CheckResource,
      Tool::CommandResource,
      Tool::SyncResource,
      Tool::ExportItems,
      Tool::ListRuns,
      Tool::CancelRun
    ]
  end
end
