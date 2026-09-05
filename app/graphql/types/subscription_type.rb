# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :item_analyzed, subscription: Subscriptions::ItemAnalyzed, grants: "uris:catalog:read"
  end
end
