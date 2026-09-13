module Tool
  class Search < Base
    tool_name "search"
    scope "uris:catalog:read"

    description <<~TEXT
      Search the whole catalog at once — every resource that has been synced, not one
      provider at a time. Matches titles, keys, paths, tags and text drawn out by analysis.
      Omit the query to list the most recent feeds of a type.
    TEXT

    input_schema(
      properties: {
        query: { type: "string", description: "Words to match. All of them must appear." },
        type: {
          type: "string",
          description: "Restrict to one type: uris:file, uris:note, uris:feed, uris:tag, uris:mime."
        },
        limit: { type: "integer", minimum: 1, maximum: 200 }
      }
    )

    GIST = 300

    def self.found(feed)
      summarize(feed).merge(gist: (feed.summary || feed.body_text)&.squish&.truncate(GIST))
    end

    def self.call(server_context:, query: nil, type: nil, limit: 50)
      respond(server_context, { query: query, type: type, limit: limit }) do
        feeds = Feed.search(query, type: type, limit: limit.to_i.clamp(1, 200))
                    .reject { |feed| feed.id == Current.acting_for }

        { count: feeds.size, feeds: feeds.map { |feed| found(feed) } }
      end
    end
  end
end
