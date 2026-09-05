# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :item_analyzed, subscription: Subscriptions::ItemAnalyzed, grants: "items:catalog:read"
  end
end
