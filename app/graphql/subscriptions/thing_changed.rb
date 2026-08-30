# frozen_string_literal: true

module Subscriptions
  class ThingChanged < BaseSubscription
    field :thing, Types::ThingType, null: false

    def subscribe
      :no_response
    end

    def update(**)
      { thing: object }
    end
  end
end
