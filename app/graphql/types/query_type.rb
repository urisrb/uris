# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    field :tenant, Types::TenantType, null: true,
      description: "The tenant this request resolved to"

    def tenant
      context[:tenant]
    end

    field :things, [ Types::ThingType ], null: false,
      description: "Everything in this tenant's catalog" do
        argument :kind, String, required: false
      end

    def things(kind: nil)
      scope = Thing.order(created_at: :desc)
      scope = scope.where(kind: kind) if kind
      scope.limit(100)
    end
  end
end
