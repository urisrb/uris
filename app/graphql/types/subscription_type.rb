# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :thing_changed, subscription: Subscriptions::ThingChanged
  end
end
