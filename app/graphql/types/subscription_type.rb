# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :feed_analyzed, subscription: Subscriptions::FeedAnalyzed, grants: "uris:catalog:read"
    field :analysis_progressed, subscription: Subscriptions::AnalysisProgressed,
          grants: "uris:catalog:read"
    field :run_progressed, subscription: Subscriptions::RunProgressed, grants: "uris:catalog:read"
  end
end
