# frozen_string_literal: true

module Types
  class AnalysisPageType < Types::BaseObject
    field :nodes, [ Types::AnalysisType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
    field :total, Integer
  end
end
