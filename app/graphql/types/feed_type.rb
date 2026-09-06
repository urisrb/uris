# frozen_string_literal: true

module Types
  class FeedType < Types::BaseObject
    grants "uris:catalog:read"

    field :id, ID, null: false
    field :slug, String, null: false
    field :name, String
    field :prompt, String, null: false
    field :role, String, null: false
    field :turns, Integer
    field :interval, Integer, description: "Seconds between runs. Null when it only runs by hand."
    field :next_run_at, GraphQL::Types::ISO8601DateTime
    field :paused_at, GraphQL::Types::ISO8601DateTime
    field :ran_at, GraphQL::Types::ISO8601DateTime
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    field :scheduled, Boolean, null: false
    field :items_count, Integer, null: false
    field :items, [ Types::ItemType ], null: false
    field :runs, [ Types::RunType ], null: false

    def scheduled = object.scheduled?

    def items_count = object.feed_items.count

    def items
      object.items.order(created_at: :desc).limit(200)
    end

    def runs
      object.runs.order(created_at: :desc).limit(20)
    end
  end
end
