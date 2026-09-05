# frozen_string_literal: true

module Subscriptions
  class ItemAnalyzed < BaseSubscription
    argument :id, ID, required: false,
             description: "Watch one item. Left off, every item in the tenant."

    field :item, Types::ItemType, null: false

    def subscribe(id: nil)
      :no_response
    end

    def update(id: nil)
      { item: object }
    end
  end
end
