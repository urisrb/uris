module Tool
  class SearchItems < Base
    tool_name "search_items"
    scope "items:catalog:read"

    description <<~TEXT
      Search the whole catalog at once — every resource that has been synced, not one
      provider at a time. Matches titles, paths, and text extracted by analysis.
      Omit the query to list the most recent items of a kind.
    TEXT

    input_schema(
      properties: {
        query: { type: "string", description: "Words to match. All of them must appear." },
        kind: {
          type: "string",
          description: "Restrict to one kind of item: pdf, image, text, data, xlsx, doc, email, calendar, file."
        },
        limit: { type: "integer", minimum: 1, maximum: 200 }
      }
    )

    def self.call(server_context:, query: nil, kind: nil, limit: 50)
      respond(server_context, { query: query, kind: kind, limit: limit }) do
        items = Item.search(query, kind: kind, limit: limit.clamp(1, 200))

        { count: items.size, items: items.map { |item| summarize(item) } }
      end
    end
  end
end
