# frozen_string_literal: true

module Types
  class RunPageType < Types::BaseObject
    field :nodes, [ Types::RunType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
  end
end
