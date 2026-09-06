require "monitor"

class FakeSearchEngine
  Errors = OpenSearch::Transport::Transport::Errors

  class Indices
    def initialize(engine)
      @engine = engine
    end

    def create(index:, body: {}, **)
      @engine.create_index!(index, body)
    end

    def exists(index:, **)
      @engine.known?(index)
    end

    def delete(index:, ignore: nil, **)
      @engine.delete_index!(index, Array(ignore))
    end

    def get_alias(name:, **)
      @engine.carrying(name)
    end

    def update_aliases(body:, **)
      @engine.update_aliases!(body)
    end

    def refresh(index:, **)
      @engine.resolve!(index)
      { "_shards" => { "successful" => 1 } }
    end
  end

  def initialize
    @indices = {}
    @documents = {}
    @monitor = Monitor.new
  end

  def indices
    @wrapper ||= Indices.new(self)
  end

  def index(index:, id:, body:, **)
    @monitor.synchronize do
      name, = resolve!(index)
      @documents[name][id.to_s] = normalize(body)

      { "_index" => name, "_id" => id.to_s, "result" => "created" }
    end
  end

  def bulk(body:, **)
    @monitor.synchronize do
      items = body.each_slice(2).map do |action, document|
        written = normalize(action).fetch("index")
        name, = resolve!(written["_index"])
        id = written["_id"].to_s
        @documents[name][id] = normalize(document)

        { "index" => { "_index" => name, "_id" => id, "status" => 201 } }
      end

      { "errors" => false, "items" => items }
    end
  end

  def delete(index:, id:, **)
    @monitor.synchronize do
      name, = resolve!(index)
      raise Errors::NotFound, "no document #{id} in #{index}" unless @documents[name].delete(id.to_s)

      { "_index" => name, "_id" => id.to_s, "result" => "deleted" }
    end
  end

  def delete_by_query(index:, body:, **)
    @monitor.synchronize do
      name, filter = resolve!(index)
      found = matching(name, filter, normalize(body))
      found.each { |id, _| @documents[name].delete(id) }

      { "deleted" => found.length }
    end
  end

  def count(index:, **)
    @monitor.synchronize do
      name, filter = resolve!(index)

      { "count" => matching(name, filter, {}).length }
    end
  end

  def search(index:, body: {}, **)
    @monitor.synchronize do
      name, filter = resolve!(index)
      asked = normalize(body)
      found = matching(name, filter, asked)
      window = found.drop(asked["from"].to_i).first(asked["size"] || 10)

      {
        "hits" => {
          "total" => { "value" => found.length },
          "hits" => window.map do |id, document|
            { "_index" => name, "_id" => id, "_score" => 1.0, "_source" => document }
          end
        }
      }
    end
  end

  def create_index!(name, body)
    @monitor.synchronize do
      if @indices.key?(name)
        raise Errors::BadRequest, "resource_already_exists_exception: #{name} exists already"
      end

      @indices[name] = {}
      @documents[name] = {}

      { "acknowledged" => true, "index" => name }
    end
  end

  def delete_index!(name, ignore)
    @monitor.synchronize do
      unless @indices.key?(name)
        raise Errors::NotFound, "no such index #{name}" unless ignore.include?(404)

        return { "acknowledged" => true }
      end

      @indices.delete(name)
      @documents.delete(name)

      { "acknowledged" => true }
    end
  end

  def known?(name)
    @monitor.synchronize { @indices.key?(name) || @indices.any? { |_, held| held.key?(name) } }
  end

  def carrying(name)
    @monitor.synchronize do
      found = @indices.select { |_, held| held.key?(name) }
      raise Errors::NotFound, "no index carries #{name}" if found.empty?

      found.transform_values { |held| { "aliases" => held.transform_values { |filter| filter || {} } } }
    end
  end

  def update_aliases!(body)
    @monitor.synchronize do
      normalize(body).fetch("actions").each do |action|
        added = action["add"]
        removed = action["remove"]

        add_alias!(added) if added
        remove_alias!(removed) if removed
      end

      { "acknowledged" => true }
    end
  end

  def resolve!(name)
    name = name.to_s

    @monitor.synchronize do
      return [ name, nil ] if @indices.key?(name)

      carrier = @indices.find { |_, held| held.key?(name) }
      raise Errors::NotFound, "no such index or alias #{name}" if carrier.nil?

      [ carrier.first, carrier.last[name] ]
    end
  end

  private

    def add_alias!(action)
      name = action.fetch("index")
      raise Errors::NotFound, "no such index #{name}" unless @indices.key?(name)

      @indices[name][action.fetch("alias")] = action["filter"]
    end

    def remove_alias!(action)
      held = @indices[action.fetch("index")]
      return if held.nil?

      wanted = action.fetch("alias")

      if wanted.end_with?("*")
        held.delete_if { |name, _| name.start_with?(wanted.chomp("*")) }
      else
        held.delete(wanted)
      end
    end

    def matching(name, filter, body)
      query = body.dig("query") || { "match_all" => {} }

      @documents.fetch(name, {})
        .select { |_, document| clause?(document, filter) && clause?(document, query) }
        .sort_by { |id, _| id.to_i }
    end

    def clause?(document, query)
      return true if query.nil? || query.empty?

      name, held = query.first

      case name
      when "match_all" then true
      when "bool" then Array(held["must"]).all? { |one| clause?(document, one) }
      when "term" then held.all? { |field, value| document[field].to_s == value.to_s }
      when "multi_match" then multi_match?(document, held)
      else raise ArgumentError, "the fake engine does not understand #{name}"
      end
    end

    def multi_match?(document, held)
      wanted = terms(held["query"])
      return true if wanted.empty?

      held.fetch("fields").any? do |field|
        found = terms(document[field.split("^").first])
        wanted.all? { |term| found.include?(term) }
      end
    end

    def terms(value)
      value.to_s.downcase.split(/[^a-z0-9]+/).reject(&:empty?)
    end

    def normalize(value)
      value.deep_stringify_keys
    end
end
