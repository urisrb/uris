# frozen_string_literal: true

module Subscriptions
  class BaseSubscription < GraphQL::Schema::Subscription
    object_class Types::BaseObject
    field_class Types::BaseField
    argument_class Types::BaseArgument

    # Scoped here so it cannot be forgotten per-subscription: without it
    # graphql-ruby derives the topic from the field and its arguments alone,
    # and two tenants share one cable stream.
    subscription_scope :tenant_id
  end
end
