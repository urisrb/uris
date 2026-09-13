class Reach
  def engines
    @engines ||= Resource.capable_of(:search).pluck(:key)
  end

  def fetchers
    @fetchers ||= Resource.capable_of(:fetch).pluck(:key)
  end

  def keepers
    @keepers ||= Resource.capable_of(:browser).pluck(:key)
  end

  def web?
    engines.any? || fetchers.any?
  end

  def readable?
    fetchers.any? || keepers.any?
  end

  def told
    return nil unless web?

    [
      (%(Search it with resource, do=search, key #{quoted(engines)}, input {"query": "..."}.) if engines.any?),
      (%(Read a page with resource, do=get, key #{quoted(fetchers)}, input {"url": "https://..."}.) if fetchers.any?)
    ].compact.join(" ")
  end

  def keeping
    return nil if keepers.empty?

    %(Keep a page worth having again with resource, do=snapshot, key #{quoted(keepers)}, input {"url": "https://..."}.)
  end

  def searched?(call) = called?(call, "search", engines)
  def fetched?(call) = called?(call, "get", fetchers)
  def kept?(call) = called?(call, "snapshot", keepers)

  def read?(call)
    fetched?(call) || kept?(call)
  end

  def read_call(url)
    return { do: "get", key: fetchers.first, input: { url: url } } if fetchers.any?

    { do: "snapshot", key: keepers.first, input: { url: url } }
  end

  def keep_call(url)
    { do: "snapshot", key: keepers.first, input: { url: url } }
  end

  private

    def called?(call, verb, keys)
      return false unless call.ok && call.name == "resource"

      held = call.arguments.to_h.transform_keys(&:to_s)
      held["do"] == verb && keys.include?(held["key"])
    end

    def quoted(keys)
      keys.map { |key| %("#{key}") }.join(" or ")
    end
end
