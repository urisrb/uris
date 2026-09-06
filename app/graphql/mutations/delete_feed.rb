# frozen_string_literal: true

module Mutations
  class DeleteFeed < BaseMutation
    argument :id, ID, required: true

    field :deleted, Boolean, null: false
    field :kept, Integer, null: false,
          description: "How many items it wrote that outlive it."

    def resolve(id:)
      feed = Feed.find_by(id: id) || refused("no feed with id #{id}")
      slug = feed.slug
      kept = feed.minted_items.count

      feed.destroy!

      noted(slug, kept)

      { deleted: true, kept: kept }
    end

    private

      def noted(slug, kept)
        AuditEvent.record(
          channel: "graphql", action: "delete_feed", status: "ok",
          grant: context[:grant], context: Current.audit,
          arguments: { "slug" => slug, "kept" => kept }
        )
      end
  end
end
