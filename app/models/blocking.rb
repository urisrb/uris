module Blocking
  # Comparing every thing to every other is quadratic, so nothing is compared
  # until a cheap key says two things might be the same. Both keys here are
  # computed from columns that already exist and are grouped by the database.
  #
  #   same-name   kind plus the basename of the locator key. A file copied
  #               between two resources keeps its name and loses its path.
  #   same-bytes  the version a resource reports for those bytes, scoped to
  #               the resource type that minted it — an etag from S3 and an
  #               etag from WebDAV mean different things and must not collide.
  #
  # Neither is proof. They are the blocking step; a person or an agent decides.
  KEYS = {
    "same-name" => <<~SQL.squish,
      concat('same-name:', things.kind, ':',
             lower(regexp_replace(thing_references.locator_key, '^.*/', '')))
    SQL
    "same-bytes" => <<~SQL.squish
      concat('same-bytes:', resources.type, ':', thing_references.version)
    SQL
  }.freeze

  WHERE = {
    "same-name" => "thing_references.locator_key IS NOT NULL AND thing_references.locator_key <> ''",
    "same-bytes" => "thing_references.version IS NOT NULL AND thing_references.version <> ''"
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
                 array_agg(DISTINCT things.id) AS thing_ids
          FROM things
          JOIN thing_references ON thing_references.thing_id = things.id
          JOIN resources ON resources.id = thing_references.resource_id
          WHERE #{WHERE[reason]}
          GROUP BY blocking_key
          HAVING count(DISTINCT things.id) > 1 AND #{KEYS[reason]} > ?
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
