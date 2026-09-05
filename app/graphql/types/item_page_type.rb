# frozen_string_literal: true

module Types
  class ItemPageType < Types::BaseObject
    field :nodes, [ Types::ItemType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
  end
end
