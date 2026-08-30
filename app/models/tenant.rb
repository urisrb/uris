class Tenant < ApplicationRecord
  has_many :things, dependent: :destroy

  validates :subdomain, presence: true, uniqueness: true,
                        format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :name, presence: true

  class << self
    # Resolve from the request host rather than from a record. Inferring the
    # tenant from the data you are about to read is how cross-tenant reads
    # start looking legitimate.
    def resolve(host)
      subdomain = host.to_s.split(".").first
      find_by(subdomain: subdomain)
    end

    # Everything that touches tenant-scoped data runs inside this. It sets both
    # halves of the enforcement: Current.tenant for the application scopes, and
    # the Postgres session variable the RLS policies read.
    #
    # SET LOCAL is scoped to the surrounding transaction, so a connection
    # returned to the pool can never carry another request's tenant.
    def switch(tenant)
      raise ArgumentError, "no tenant" if tenant.nil?

      previous = Current.tenant

      # requires_new opens a savepoint. A policy violation inside the block
      # then rolls back to it instead of poisoning the surrounding
      # transaction — which matters because the caller is often a test, or a
      # request that wants to render an error rather than die.
      ActiveRecord::Base.transaction(requires_new: true) do
        assign_tenant_setting(tenant.id)
        Current.tenant = tenant

        begin
          yield tenant
        ensure
          Current.tenant = previous
          clear_tenant_setting
        end
      end
    end

    private

      # set_config with local: true is SET LOCAL, but takes a bind parameter —
      # SET does not.
      def assign_tenant_setting(id)
        connection.exec_query(
          "SELECT set_config('things.tenant_id', $1, true)", "tenant", [ id.to_s ]
        )
      end

      # A committed savepoint leaves the setting in place for the rest of the
      # surrounding transaction, so leaving the block has to clear it. Without
      # this, code running after a switch would still be reading as that
      # tenant.
      def clear_tenant_setting
        connection.exec_query(
          "SELECT set_config('things.tenant_id', '', true)", "tenant", []
        )
      rescue ActiveRecord::StatementInvalid
        # The transaction is already aborted; rolling back to the savepoint
        # restores the previous setting anyway.
        nil
      end
  end
end
