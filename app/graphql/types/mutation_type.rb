# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :analyze_thing, mutation: Mutations::AnalyzeThing
    field :merge_things, mutation: Mutations::MergeThings
    field :split_reference, mutation: Mutations::SplitReference

    field :sync_resource, mutation: Mutations::SyncResource
    field :check_resource, mutation: Mutations::CheckResource
    field :set_default_storage, mutation: Mutations::SetDefaultStorage
    field :set_sync_interval, mutation: Mutations::SetSyncInterval

    field :export_things, mutation: Mutations::ExportThings
    field :cancel_run, mutation: Mutations::CancelRun
  end
end
