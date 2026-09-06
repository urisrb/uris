# frozen_string_literal: true

module Mutations
  class ForgetItem < BaseMutation
    argument :id, ID, required: true

    field :forgotten, Boolean, null: false
    field :places, Integer, null: false,
          description: "How many places it lived that uris stopped pointing at."

    def resolve(id:)
      item = item!(id)
      title = item.title
      places = item.references.count

      item.destroy!

      noted(title, places)

      { forgotten: true, places: places }
    end

    private

      def noted(title, places)
        AuditEvent.record(
          channel: "graphql", action: "forget_item", status: "ok",
          grant: context[:grant], context: Current.audit,
          arguments: { "title" => title, "places" => places }
        )
      end
  end
end
