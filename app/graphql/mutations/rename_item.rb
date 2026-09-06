# frozen_string_literal: true

module Mutations
  class RenameItem < BaseMutation
    MAX_TITLE = 200

    argument :id, ID, required: true
    argument :title, String, required: true

    field :item, Types::ItemType, null: false

    def resolve(id:, title:)
      named = title.to_s.strip

      refused("an item needs something to be called") if named.empty?
      refused("that name is longer than #{MAX_TITLE} characters") if named.length > MAX_TITLE

      item = item!(id)
      item.update!(title: named)

      { item: item }
    end
  end
end
