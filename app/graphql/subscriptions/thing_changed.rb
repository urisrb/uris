# frozen_string_literal: true

module Subscriptions
  class ThingChanged < BaseSubscription
    argument :id, ID, required: false,
             description: "Watch one thing. Left off, every thing in the tenant."

    field :thing, Types::ThingType, null: false

    def subscribe(id: nil)
      :no_response
    end

    def update(id: nil)
      { thing: object }
    end
  end
end
