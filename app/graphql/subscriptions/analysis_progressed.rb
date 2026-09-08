# frozen_string_literal: true

module Subscriptions
  class AnalysisProgressed < BaseSubscription
    argument :id, ID, required: false,
             description: "Watch one pass. Left off, every pass in the tenant."

    field :analysis, Types::AnalysisType, null: false

    def subscribe(id: nil)
      :no_response
    end

    def update(id: nil)
      { analysis: object }
    end
  end
end
