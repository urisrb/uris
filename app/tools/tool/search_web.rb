module Tool
  class SearchWeb < Base
    tool_name "search_web"
    scope "uris:web:read"

    description <<~TEXT
      Search the web for what the catalog does not hold. Returns a title, an address and a
      short extract for each result, and keeps none of it — nothing found this way enters
      the catalog. Search the catalog first when the answer could already be theirs.
    TEXT

    input_schema(
      properties: {
        query: { type: "string", description: "What to look for." },
        limit: { type: "integer", minimum: 1, maximum: Resource::Search::MAX_LIMIT }
      },
      required: [ "query" ]
    )

    def self.call(server_context:, query:, limit: nil)
      respond(server_context, { query: query, limit: limit }) do
        engine = Resource.capable_of(:search).first

        raise ArgumentError, "this tenant has nothing that searches the web" if engine.nil?

        results = engine.search(query, limit: limit || Resource::Search::LIMIT)

        { count: results.size, results: results }
      end
    end
  end
end
