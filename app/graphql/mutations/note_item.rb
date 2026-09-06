# frozen_string_literal: true

module Mutations
  class NoteItem < BaseMutation
    MAX_NOTE = 10_000

    argument :id, ID, required: true
    argument :note, String, required: false,
             description: "Left off or blank, whatever was there is cleared."

    field :item, Types::ItemType, null: false

    def resolve(id:, note: nil)
      written = note.to_s.strip

      refused("that note is longer than #{MAX_NOTE} characters") if written.length > MAX_NOTE

      item = item!(id)
      item.update!(note: written.presence)

      { item: item }
    end
  end
end
