# frozen_string_literal: true

module Types
  class KindCountType < Types::BaseObject
    field :kind, String, null: false
    field :count, Integer, null: false
  end
end
