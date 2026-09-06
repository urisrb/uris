# frozen_string_literal: true

module Subscriptions
  class AgentTurned < BaseSubscription
    argument :id, ID, required: true,
             description: "Watch one run. A turn arrives as the agent takes it."

    field :turn, Integer, null: false
    field :calls, [ String ], null: false
    field :said, String, null: true

    def subscribe(id: nil)
      :no_response
    end

    def update(id: nil)
      { turn: object.number, calls: object.calls, said: object.said }
    end
  end
end
