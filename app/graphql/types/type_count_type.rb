# frozen_string_literal: true

module Types
  class TypeCountType < Types::BaseObject
    field :type, String, null: false
    field :count, Integer, null: false
  end
end
