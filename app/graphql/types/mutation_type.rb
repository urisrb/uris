# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :analyze_thing, mutation: Mutations::AnalyzeThing, grants: "things:catalog:write"
    field :merge_things, mutation: Mutations::MergeThings, grants: "things:catalog:write"
    field :split_reference, mutation: Mutations::SplitReference, grants: "things:catalog:write"
    field :propose_merges, mutation: Mutations::ProposeMerges, grants: "things:catalog:write"
    field :settle_merge_proposal, mutation: Mutations::SettleMergeProposal, grants: "things:catalog:write"

    field :sync_resource, mutation: Mutations::SyncResource, grants: "things:resources:command"
    field :check_resource, mutation: Mutations::CheckResource, grants: "things:resources:command"
    field :set_default_storage, mutation: Mutations::SetDefaultStorage, grants: "things:resources:command"
    field :set_sync_interval, mutation: Mutations::SetSyncInterval, grants: "things:resources:command"

    field :set_setting, mutation: Mutations::SetSetting, grants: "things:settings:write"

    field :export_things, mutation: Mutations::ExportThings, grants: "things:catalog:write"
    field :cancel_run, mutation: Mutations::CancelRun, grants: "things:catalog:write"
  end
end
