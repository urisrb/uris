# frozen_string_literal: true

module Types
  class ThingPageType < Types::BaseObject
    field :nodes, [ Types::ThingType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
  end
end
