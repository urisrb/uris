module SearchIndex
  SETTINGS = {
    analysis: {
      tokenizer: {
        path_parts: { type: "pattern", pattern: "[/\\\\\\-_.\\s]+" }
      },
      analyzer: {
        path: { type: "custom", tokenizer: "path_parts", filter: [ "lowercase" ] }
      }
    }
  }.freeze

  MAPPING = {
    properties: {
      tenant_id: { type: "long" },
      kind: { type: "keyword" },
      title: { type: "text", analyzer: "path" },
      locator_key: { type: "text", analyzer: "path" },
      body: { type: "text" },
      resource_id: { type: "long" },
      created_at: { type: "date" }
    }
  }.freeze

  class << self
    def client
      @client ||= OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://127.0.0.1:9201"))
    end

    def index_name
      "things_#{Rails.env}"
    end

    def alias_for(tenant)
      "#{index_name}_t#{tenant.id}"
    end

    def create!
      return if client.indices.exists(index: index_name)

      client.indices.create(index: index_name, body: { settings: SETTINGS, mappings: MAPPING })
    end

    # The tenant filter lives on the alias, so it is applied by the engine and
    # cannot be omitted by a caller. This is the search-side equivalent of RLS.
    def create_alias!(tenant)
      create!

      client.indices.put_alias(
        index: index_name,
        name: alias_for(tenant),
        body: { filter: { term: { tenant_id: tenant.id } } }
      )
    end

    def index(thing)
      client.index(
        index: index_name,
        id: thing.id,
        body: {
          tenant_id: thing.tenant_id,
          kind: thing.kind,
          title: thing.title,
          locator_key: thing.locator_key,
          body: thing.body_text,
          resource_id: thing.resource_id,
          created_at: thing.created_at
        }
      )
    end

    def delete(thing)
      client.delete(index: index_name, id: thing.id)
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      nil
    end

    def search(query, tenant: Current.tenant, kind: nil, limit: 50)
      raise ArgumentError, "no tenant" if tenant.nil?

      must = if query.present?
        [ { multi_match: { query: query, fields: %w[title^2 locator_key body], operator: "and" } } ]
      else
        [ { match_all: {} } ]
      end

      must << { term: { kind: kind } } if kind

      response = client.search(
        index: alias_for(tenant),
        body: { query: { bool: { must: must } }, size: limit }
      )

      response.dig("hits", "hits").map { |hit| hit["_id"].to_i }
    end

    def refresh!
      client.indices.refresh(index: index_name)
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      nil
    end

    def reset!
      client.indices.delete(index: index_name) if client.indices.exists(index: index_name)
      create!
    end
  end
end
