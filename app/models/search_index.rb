module SearchIndex
  class Failed < StandardError; end

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
      resource_ids: { type: "long" },
      created_at: { type: "date" }
    }
  }.freeze

  class << self
    def client
      @client ||= OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://127.0.0.1:9201"))
    end

    def alias_name
      [ "things", Rails.env, ENV["TEST_ENV_NUMBER"].presence ].compact.join("_")
    end

    def alias_for(tenant)
      "#{alias_name}_t#{tenant.id}"
    end

    def versioned
      "#{alias_name}_v#{Time.current.utc.strftime('%Y%m%d%H%M%S%L')}"
    end

    def live_indices
      client.indices.get_alias(name: alias_name).keys
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      []
    end

    def live_index
      live_indices.first || (alias_name if legacy_index?)
    end

    def legacy_index?
      live_indices.empty? && client.indices.exists(index: alias_name)
    end

    def build!(name = versioned)
      client.indices.create(index: name, body: { settings: SETTINGS, mappings: MAPPING })
      name
    rescue OpenSearch::Transport::Transport::Errors::BadRequest => e
      raise unless e.message.include?("resource_already_exists_exception")

      name
    end

    def create!
      live_index || build!.tap do |name|
        client.indices.update_aliases(
          body: { actions: [ { add: { index: name, alias: alias_name } } ] }
        )
      end
    end

    def create_alias!(tenant, index: nil)
      client.indices.update_aliases(
        body: { actions: [ tenant_alias(tenant, index || create!) ] }
      )
    end

    def promote!(target, at_least:)
      refresh!(index: target)
      held = client.count(index: target)["count"]

      if held < at_least
        raise ArgumentError, "#{target} holds #{held} documents, fewer than the #{at_least} expected"
      end

      retired = live_indices - [ target ]
      client.indices.delete(index: alias_name, ignore: 404) if legacy_index?

      actions = [ { add: { index: target, alias: alias_name } } ]
      Tenant.find_each { |tenant| actions << tenant_alias(tenant, target) }
      retired.each { |name| actions << { remove: { index: name, alias: "#{alias_name}*" } } }

      client.indices.update_aliases(body: { actions: actions })
      retired.each { |name| client.indices.delete(index: name, ignore: 404) }

      target
    end

    def index(thing, into: alias_name)
      client.index(index: into, id: thing.id, body: document(thing))
    end

    def index_all(things, into: alias_name)
      things = things.to_a
      return 0 if things.empty?

      body = things.flat_map do |thing|
        [ { index: { _index: into, _id: thing.id } }, document(thing) ]
      end

      response = client.bulk(body: body)
      refused = Array(response["items"]).filter_map { |item| item.dig("index", "error") }

      if refused.any?
        raise Failed, "#{refused.length} of #{things.length} documents were refused: " \
                      "#{refused.first['reason']}"
      end

      things.length
    end

    def delete(thing, from: alias_name)
      client.delete(index: from, id: thing.id)
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      nil
    end

    def document(thing)
      {
        tenant_id: thing.tenant_id,
        kind: thing.kind,
        title: thing.title,
        locator_key: thing.references.map(&:locator_key).compact.join(" "),
        body: thing.body_text,
        resource_ids: thing.references.map(&:resource_id),
        created_at: thing.created_at
      }
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

    def refresh!(index: alias_name)
      client.indices.refresh(index: index)
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      nil
    end

    def reset!
      indices = live_indices
      indices.each { |name| client.indices.delete(index: name, ignore: 404) }
      client.indices.delete(index: alias_name, ignore: 404) if indices.empty?

      create!
    end

    private

      def tenant_alias(tenant, index)
        {
          add: {
            index: index,
            alias: alias_for(tenant),
            filter: { term: { tenant_id: tenant.id } }
          }
        }
      end
  end
end
