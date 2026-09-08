module Tool
  class Feeds < Base
    tool_name "feed"
    scope "uris:catalog:read"
    starts_runs true

    EXCERPT = 8_000

    description <<~TEXT
      One feed: everything known about it, every place it lives, what analysis drew out of
      each, and an excerpt of its text. With `do` it also acts — note it, rename it, or
      analyze it again. A feed is a reference, not the bytes; the originals stay in the
      resources they came from.
    TEXT

    READ = %w[get].freeze
    WRITE = %w[note rename analyze create].freeze

    input_schema(
      properties: {
        id: { type: "string", description: "The feed's id, as returned by search." },
        key: { type: "string", description: "An address, as /buy, instead of an id." },
        do: {
          type: "string",
          enum: READ + WRITE,
          description: "What to do. Defaults to get."
        },
        type: { type: "string", description: "For create: uris:note, uris:feed or uris:tag." },
        title: { type: "string" },
        note: { type: "string", description: "For note: what to write about it." },
        prompt: { type: "string", description: "For create of a uris:feed: what it should find." }
      }
    )

    def self.call(server_context:, id: nil, key: nil, title: nil, note: nil,
                  type: nil, prompt: nil, **held)
      verb = (held[:do] || held["do"] || "get").to_s

      respond(server_context, { id: id, key: key, do: verb }) do
        raise ArgumentError, "no such action '#{verb}'" unless (READ + WRITE).include?(verb)

        Current.grant.permit!("uris:catalog:write") if WRITE.include?(verb)

        act(verb, id: id, key: key, title: title, note: note, type: type, prompt: prompt)
      end
    end

    def self.act(verb, id:, key:, title:, note:, type:, prompt:)
      return made(type: type, key: key, title: title, prompt: prompt) if verb == "create"

      feed = found(id, key)

      case verb
      when "note" then feed.update!(note: note.presence)
      when "rename" then feed.update!(title: title.to_s.strip.presence || feed.title)
      when "analyze" then return summarize(feed).merge(analysis: feed.analyze!(cause: "manual").id.to_s)
      end

      told(feed)
    end

    def self.found(id, key)
      return feed!(id) if id.present?

      Feed.address(key) || Feed.by_key(key.to_s).first ||
        raise(ArgumentError, "no feed at #{key}")
    end

    def self.made(type:, key:, title:, prompt:)
      wanted = type.presence || Feed::NOTE
      feed = Feed.create!(type: wanted, key: key.presence || title.to_s, title: title)

      feed.create_schedule!(prompt: prompt) if wanted == Feed::ADDRESS && prompt.present?

      told(feed)
    end

    def self.told(feed)
      summarize(feed).merge(
        note: feed.note,
        summary: feed.summary,
        keywords: feed.keywords,
        tags: feed.tags.map(&:key),
        connected: feed.connected.limit(50).map { |held| { id: held.id.to_s, key: held.key } },
        steps: feed.analysis&.steps.to_h.transform_values { |step|
          step.key?("error") ? { "error" => step["error"]["message"] } : step["result"]
        },
        text: feed.body_text&.truncate(EXCERPT)
      )
    end
  end
end
