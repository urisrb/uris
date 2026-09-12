# frozen_string_literal: true

module Types
  class AnalysisType < Types::BaseObject
    grants "uris:catalog:read"

    field :id, ID, null: false
    field :cause, String, null: false
    field :status, String, null: false
    field :steps, GraphQL::Types::JSON, null: false
    field :turns, GraphQL::Types::JSON, null: false
    field :lines, Integer, null: false
    field :logs, String,
          description: "Everything the pass has logged so far, newest last."
    field :error, String
    field :started_at, GraphQL::Types::ISO8601DateTime
    field :finished_at, GraphQL::Types::ISO8601DateTime
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :duration_ms, Integer
    field :said, String, description: "What the agent answered when the pass finished, if it ran."

    def said
      object.step_result("answer").to_h["said"].presence || last_agent_word
    end

    def last_agent_word
      spoken = object.turns.select { |turn| turn["role"] == "agent" && turn["calls"].blank? }

      spoken.last&.dig("content").presence
    end
  end
end
