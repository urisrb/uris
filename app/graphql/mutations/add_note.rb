# frozen_string_literal: true

module Mutations
  class AddNote < BaseMutation
    MAX_BODY = 1.megabyte
    TITLE_FROM_BODY = 80

    argument :title, String, required: false,
             description: "Left off, the first line of the note names it."
    argument :body, String, required: true

    field :item, Types::ItemType, null: false

    def resolve(body:, title: nil)
      text = body.to_s
      refused("a note needs something in it") if text.strip.empty?
      refused("that note is longer than #{MAX_BODY} bytes") if text.bytesize > MAX_BODY

      named = title.presence || first_line(text)
      landed = Intake.write!(
        path: Intake.filed("notes", "#{named}.md"),
        body: text,
        kind: "text",
        title: named
      )

      { item: landed.item }
    rescue Intake::Unusable, Resource::Failed => e
      refused(e.message)
    end

    private

      def first_line(text)
        text.lines.first.to_s.strip.delete_prefix("#").strip.truncate(TITLE_FROM_BODY).presence || "Note"
      end
  end
end
