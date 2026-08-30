# Keyset pagination on the primary key, newest first. There is no offset and no
# count: the cursor is the last id of the previous page, and one extra row is
# fetched to answer "is there more" without asking the database to count a
# million things.
class Page
  DEFAULT = 50
  MAX = 200

  attr_reader :nodes, :has_more

  def self.of(scope, after: nil, limit: nil)
    size = (limit || DEFAULT).to_i.clamp(1, MAX)
    scope = scope.reorder(id: :desc)
    scope = scope.where(id: ...after.to_i) if after.present?

    rows = scope.limit(size + 1).to_a

    new(rows.first(size), rows.size > size)
  end

  def initialize(nodes, has_more)
    @nodes = nodes
    @has_more = has_more
  end

  def next_cursor
    nodes.last&.id&.to_s if has_more
  end
end
