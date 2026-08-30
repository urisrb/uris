# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :analyze_thing, mutation: Mutations::AnalyzeThing, grants: "things:write"
    field :merge_things, mutation: Mutations::MergeThings, grants: "things:write"
    field :split_reference, mutation: Mutations::SplitReference, grants: "things:write"

    field :sync_resource, mutation: Mutations::SyncResource, grants: "resources:command"
    field :check_resource, mutation: Mutations::CheckResource, grants: "resources:command"
    field :set_default_storage, mutation: Mutations::SetDefaultStorage, grants: "resources:command"
    field :set_sync_interval, mutation: Mutations::SetSyncInterval, grants: "resources:command"

    field :export_things, mutation: Mutations::ExportThings, grants: "things:write"
    field :cancel_run, mutation: Mutations::CancelRun, grants: "things:write"
  end
end
