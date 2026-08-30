# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    field :tenant, Types::TenantType, null: true

    def tenant
      context[:tenant]
    end

    field :thing, Types::ThingType, null: true do
      argument :id, ID, required: true
    end

    def thing(id:)
      Thing.find_by(id: id)
    end

    field :things, Types::ThingPageType, null: false do
      argument :kind, String, required: false
      argument :resource_id, ID, required: false
      argument :after, ID, required: false
      argument :limit, Integer, required: false
    end

    def things(kind: nil, resource_id: nil, after: nil, limit: nil)
      scope = Thing.all
      scope = scope.where(kind: kind) if kind.present?
      scope = scope.referencing(resource_id) if resource_id.present?

      Page.of(scope, after: after, limit: limit)
    end

    field :search, [ Types::ThingType ], null: false do
      argument :query, String, required: false
      argument :kind, String, required: false
      argument :limit, Integer, required: false
    end

    def search(query: nil, kind: nil, limit: nil)
      Thing.search(query, kind: kind, limit: (limit || 50).to_i.clamp(1, 200))
    end

    field :kinds, [ Types::KindCountType ], null: false

    def kinds
      Thing.group(:kind).order(count_all: :desc).count.map do |kind, count|
        { kind: kind, count: count }
      end
    end

    field :resources, [ Types::ResourceType ], null: false

    def resources
      Resource.active.order(:type, :key)
    end

    field :runs, Types::RunPageType, null: false do
      argument :kind, String, required: false
      argument :status, String, required: false
      argument :after, ID, required: false
      argument :limit, Integer, required: false
    end

    def runs(kind: nil, status: nil, after: nil, limit: nil)
      scope = Run.all
      scope = scope.where(kind: kind) if kind.present?
      scope = scope.where(status: status) if status.present?

      Page.of(scope, after: after, limit: limit)
    end
  end
end
