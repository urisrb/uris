# frozen_string_literal: true

module Subscriptions
  class RunProgressed < BaseSubscription
    argument :id, ID, required: false,
             description: "Watch one run. Left off, every run in the tenant."

    field :run, Types::RunType, null: false

    def subscribe(id: nil)
      :no_response
    end

    def update(id: nil)
      return :no_update unless Run.visible_to(context[:grant]).exists?(id: object.id)

      { run: object }
    end
  end
end
