# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :tenant, Types::TenantType, null: true, grants: "uris:catalog:read"

    def tenant
      context[:tenant]
    end

    field :settings, [ Types::SettingType ], null: false, grants: "uris:settings:read"

    def settings
      grant = context[:grant]
      subject = grant.subject

      Setting::LEVELS.flat_map { |level| Setting.at(level) }
                     .select { |definition| grant.permits?(definition.reads) }
                     .map do |definition|
        definition.to_h.merge(value: Setting.read(definition.key, subject: subject))
      end
    end

    field :item, Types::ItemType, null: true, grants: "uris:catalog:read" do
      argument :id, ID, required: true
    end

    def item(id:)
      Item.find_by(id: id)
    end

    field :items, Types::ItemPageType, null: false, grants: "uris:catalog:read" do
      argument :kind, String, required: false
      argument :resource_id, ID, required: false
      argument :after, ID, required: false
      argument :limit, Integer, required: false
    end

    def items(kind: nil, resource_id: nil, after: nil, limit: nil)
      scope = Item.all
      scope = scope.where(kind: kind) if kind.present?
      scope = scope.referencing(resource_id) if resource_id.present?

      Page.of(scope, after: after, limit: limit)
    end

    field :search, [ Types::ItemType ], null: false, grants: "uris:catalog:read" do
      argument :query, String, required: false
      argument :kind, String, required: false
      argument :limit, Integer, required: false
    end

    def search(query: nil, kind: nil, limit: nil)
      Item.search(query, kind: kind, limit: (limit || 50).to_i.clamp(1, 200))
    end

    field :kinds, [ Types::KindCountType ], null: false, grants: "uris:catalog:read"

    def kinds
      Item.group(:kind).order(count_all: :desc).count.map do |kind, count|
        { kind: kind, count: count }
      end
    end

    field :resources, [ Types::ResourceType ], null: false, grants: "uris:resources:read"

    def resources
      Resource.active.order(:type, :key)
    end

    field :runs, Types::RunPageType, null: false, grants: "uris:catalog:read" do
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

    field :merge_proposals, Types::MergeProposalPageType, null: false, grants: "uris:catalog:read" do
      argument :status, String, required: false
      argument :after, ID, required: false
      argument :limit, Integer, required: false
    end

    def merge_proposals(status: nil, after: nil, limit: nil)
      scope = MergeProposal.where(status: status.presence || "open")

      Page.of(scope, after: after, limit: limit)
    end

    field :audit_events, Types::AuditEventPageType, null: false, grants: "uris:catalog:read" do
      argument :action, String, required: false
      argument :status, String, required: false
      argument :subject, String, required: false
      argument :after, ID, required: false
      argument :limit, Integer, required: false
    end

    def audit_events(action: nil, status: nil, subject: nil, after: nil, limit: nil)
      scope = AuditEvent.all
      scope = scope.where(action: action) if action.present?
      scope = scope.where(status: status) if status.present?
      scope = scope.where(subject: subject) if subject.present?

      Page.of(scope, after: after, limit: limit)
    end
  end
end
