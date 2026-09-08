class AMimeTypeIsAFeed < ActiveRecord::Migration[8.1]
  include TenantIsolation

  SINGLETON = "index_feeds_on_one_row_per_address".freeze
  SERVED = %w[uris:tag uris:feed uris:mime].freeze

  def up
    without_row_level_security(:feeds, :feed_edges) do
      execute <<~SQL
        DELETE FROM feed_edges WHERE a_id IN (
          SELECT id FROM feeds WHERE type = 'uris:tag' AND key LIKE '%/%'
        ) OR b_id IN (
          SELECT id FROM feeds WHERE type = 'uris:tag' AND key LIKE '%/%'
        );
        DELETE FROM feeds WHERE type = 'uris:tag' AND key LIKE '%/%';
      SQL
    end

    restate(SERVED)
  end

  def down
    without_row_level_security(:feeds, :feed_edges) do
      execute <<~SQL
        DELETE FROM feed_edges WHERE a_id IN (
          SELECT id FROM feeds WHERE type = 'uris:mime'
        ) OR b_id IN (
          SELECT id FROM feeds WHERE type = 'uris:mime'
        );
        DELETE FROM feeds WHERE type = 'uris:mime';
      SQL
    end

    restate(SERVED - [ "uris:mime" ])
  end

  private

    def restate(types)
      remove_index :feeds, name: SINGLETON
      add_index :feeds, [ :tenant_id, :type, :key ], unique: true,
                where: "type IN (#{types.map { |held| "'#{held}'" }.join(', ')})",
                name: SINGLETON
    end
end
