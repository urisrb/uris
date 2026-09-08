module Tool
  class Connect < Base
    tool_name "connect"
    scope "uris:catalog:write"

    description <<~TEXT
      Connect two feeds, or sever the connection. A connection is symmetric and carries no
      direction — what it means is read from the two things joined. Connecting a document to
      a tag is how it is filed; connecting it to another document is how they are related.
    TEXT

    input_schema(
      properties: {
        a: { type: "string", description: "One feed's id." },
        b: { type: "string", description: "The other feed's id." },
        connected: {
          type: "boolean",
          description: "False severs the connection instead of making it. Defaults to true."
        }
      },
      required: [ "a", "b" ]
    )

    def self.call(a:, b:, server_context:, connected: true)
      respond(server_context, { a: a, b: b, connected: connected }) do
        one = feed!(a)
        other = feed!(b)

        raise ArgumentError, "a feed cannot connect to itself" if one.id == other.id

        connected ? one.connect!(other) : one.disconnect!(other)

        { connected: connected, a: summarize(one), b: summarize(other) }
      end
    end
  end
end
