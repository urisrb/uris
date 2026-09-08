module Blocking
  KEYS = {
    "same-name" => <<~SQL.squish,
      concat('same-name:', feeds.type, ':', lower(feeds.key))
    SQL
    "same-bytes" => <<~SQL.squish
      concat('same-bytes:', resources.type, ':', feed_references.version)
    SQL
  }.freeze

  WHERE = {
    "same-name" => "feeds.key IS NOT NULL AND feeds.key <> ''",
    "same-bytes" => "feed_references.version IS NOT NULL AND feed_references.version <> ''"
  }.freeze

  class << self
    def groups_after(cursor, limit:)
      rows = KEYS.keys.flat_map { |reason| query(reason, cursor, limit) }

      rows.sort_by { |row| row["blocking_key"] }.first(limit)
    end

    private

      def query(reason, cursor, limit)
        sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, cursor.to_s, limit ])
          SELECT #{KEYS[reason]} AS blocking_key,
                 array_agg(DISTINCT feeds.id) AS feed_ids
          FROM feeds
          JOIN feed_references ON feed_references.feed_id = feeds.id
                              AND feed_references.role = 'original'
          JOIN resources ON resources.id = feed_references.resource_id
          WHERE #{WHERE[reason]}
          GROUP BY blocking_key
          HAVING count(DISTINCT feeds.id) > 1 AND #{KEYS[reason]} > ?
          ORDER BY blocking_key
          LIMIT ?
        SQL

        ActiveRecord::Base.connection.select_all(sql).to_a.each do |row|
          row["reason"] = reason
          row["feed_ids"] = parse_ids(row["feed_ids"])
        end
      end

      def parse_ids(value)
        return value if value.is_a?(Array)

        value.to_s.delete("{}").split(",").map(&:to_i)
      end
  end
end
