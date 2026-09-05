module Blocking
  KEYS = {
    "same-name" => <<~SQL.squish,
      concat('same-name:', items.kind, ':',
             lower(regexp_replace(item_references.locator_key, '^.*/', '')))
    SQL
    "same-bytes" => <<~SQL.squish
      concat('same-bytes:', resources.type, ':', item_references.version)
    SQL
  }.freeze

  WHERE = {
    "same-name" => "item_references.locator_key IS NOT NULL AND item_references.locator_key <> ''",
    "same-bytes" => "item_references.version IS NOT NULL AND item_references.version <> ''"
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
                 array_agg(DISTINCT items.id) AS thing_ids
          FROM items
          JOIN item_references ON item_references.item_id = items.id
          JOIN resources ON resources.id = item_references.resource_id
          WHERE #{WHERE[reason]}
          GROUP BY blocking_key
          HAVING count(DISTINCT items.id) > 1 AND #{KEYS[reason]} > ?
          ORDER BY blocking_key
          LIMIT ?
        SQL

        ActiveRecord::Base.connection.select_all(sql).to_a.each do |row|
          row["reason"] = reason
          row["thing_ids"] = parse_ids(row["thing_ids"])
        end
      end

      def parse_ids(value)
        return value if value.is_a?(Array)

        value.to_s.delete("{}").split(",").map(&:to_i)
      end
  end
end
