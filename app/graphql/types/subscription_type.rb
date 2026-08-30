# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :thing_analyzed, subscription: Subscriptions::ThingAnalyzed, grants: "things:read"
  end
end
