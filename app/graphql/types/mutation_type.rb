# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :analyze_item, mutation: Mutations::AnalyzeItem, grants: "uris:catalog:write"
    field :merge_items, mutation: Mutations::MergeItems, grants: "uris:catalog:write"
    field :split_reference, mutation: Mutations::SplitReference, grants: "uris:catalog:write"
    field :propose_merges, mutation: Mutations::ProposeMerges, grants: "uris:catalog:write"
    field :settle_merge_proposal, mutation: Mutations::SettleMergeProposal, grants: "uris:catalog:write"

    field :sync_resource, mutation: Mutations::SyncResource, grants: "uris:resources:command"
    field :check_resource, mutation: Mutations::CheckResource, grants: "uris:resources:command"
    field :set_default_storage, mutation: Mutations::SetDefaultStorage, grants: "uris:resources:command"
    field :set_default_inference, mutation: Mutations::SetDefaultInference, grants: "uris:resources:command"
    field :set_sync_interval, mutation: Mutations::SetSyncInterval, grants: "uris:resources:command"

    field :set_setting, mutation: Mutations::SetSetting, grants: "uris:settings:write"

    field :export_items, mutation: Mutations::ExportItems, grants: "uris:catalog:write"
    field :cancel_run, mutation: Mutations::CancelRun, grants: "uris:catalog:write"
  end
end
