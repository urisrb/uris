# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :analyze_item, mutation: Mutations::AnalyzeItem, grants: "items:catalog:write"
    field :merge_items, mutation: Mutations::MergeItems, grants: "items:catalog:write"
    field :split_reference, mutation: Mutations::SplitReference, grants: "items:catalog:write"
    field :propose_merges, mutation: Mutations::ProposeMerges, grants: "items:catalog:write"
    field :settle_merge_proposal, mutation: Mutations::SettleMergeProposal, grants: "items:catalog:write"

    field :sync_resource, mutation: Mutations::SyncResource, grants: "items:resources:command"
    field :check_resource, mutation: Mutations::CheckResource, grants: "items:resources:command"
    field :set_default_storage, mutation: Mutations::SetDefaultStorage, grants: "items:resources:command"
    field :set_default_inference, mutation: Mutations::SetDefaultInference, grants: "items:resources:command"
    field :set_sync_interval, mutation: Mutations::SetSyncInterval, grants: "items:resources:command"

    field :set_setting, mutation: Mutations::SetSetting, grants: "items:settings:write"

    field :export_items, mutation: Mutations::ExportItems, grants: "items:catalog:write"
    field :cancel_run, mutation: Mutations::CancelRun, grants: "items:catalog:write"
  end
end
