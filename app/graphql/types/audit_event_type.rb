# frozen_string_literal: true

module Types
  class AuditEventType < Types::BaseObject
    grants "things:read"

    field :id, ID, null: false
    field :channel, String, null: false
    field :action, String, null: false
    field :status, String, null: false
    field :scope, String
    field :subject, String
    field :client_id, String
    field :remote_ip, String
    field :request_id, String
    field :duration_ms, Integer
    field :detail, String
    field :arguments, GraphQL::Types::JSON, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :run, Types::RunType
  end
end
