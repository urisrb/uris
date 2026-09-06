# frozen_string_literal: true

module Types
  class ItemPageType < Types::BaseObject
    field :nodes, [ Types::ItemType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
    field :total, Integer,
          description: "How many match altogether, where the source can count them. " \
                       "A search can; walking the catalog by cursor cannot."
  end
end
