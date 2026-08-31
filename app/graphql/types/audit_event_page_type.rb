# frozen_string_literal: true

module Types
  class AuditEventPageType < Types::BaseObject
    field :nodes, [ Types::AuditEventType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
  end
end
