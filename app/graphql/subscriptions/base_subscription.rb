# frozen_string_literal: true

module Subscriptions
  class BaseSubscription < GraphQL::Schema::Subscription
    object_class Types::BaseObject
    field_class Types::BaseField
    argument_class Types::BaseArgument

    subscription_scope :tenant_id
  end
end
