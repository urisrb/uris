# frozen_string_literal: true

module Subscriptions
  class BaseSubscription < GraphQL::Schema::Subscription
    object_class Types::BaseObject
    field_class Types::BaseField
    argument_class Types::BaseArgument

    # Every subscription in this schema is scoped to a tenant, and it is scoped
    # here rather than per-subscription so it cannot be forgotten.
    #
    # Without this, graphql-ruby derives the topic from the field name and its
    # arguments alone — so two tenants subscribing to the same field share one
    # stream, and a broadcast reaches both. Cable stream names are a third path
    # that Postgres row-level security cannot protect, alongside the search
    # index.
    subscription_scope :tenant_id
  end
end
