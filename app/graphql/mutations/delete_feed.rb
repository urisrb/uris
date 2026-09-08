# frozen_string_literal: true

module Mutations
  class DeleteFeed < BaseMutation
    argument :id, ID, required: true

    field :deleted, Boolean, null: false
    field :kept, Integer, null: false,
          description: "How many feeds it minted that outlive it."

    def resolve(id:)
      feed = feed!(id)
      key = feed.key
      kept = feed.connected.minted.count

      feed.destroy!

      noted(key, kept)

      { deleted: true, kept: kept }
    end

    private

      def noted(key, kept)
        AuditEvent.record(
          channel: "graphql", action: "delete_feed", status: "ok",
          grant: context[:grant], context: Current.audit,
          arguments: { "key" => key, "kept" => kept }
        )
      end
  end
end
