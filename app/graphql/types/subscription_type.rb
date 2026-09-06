# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :item_analyzed, subscription: Subscriptions::ItemAnalyzed, grants: "uris:catalog:read"
    field :agent_turned, subscription: Subscriptions::AgentTurned, grants: "uris:catalog:read"
    field :run_progressed, subscription: Subscriptions::RunProgressed, grants: "uris:catalog:read"
  end
end
