# frozen_string_literal: true

class ThingsSchema < GraphQL::Schema
  query(Types::QueryType)
  mutation(Types::MutationType)
  subscription(Types::SubscriptionType)

  # Live progress over ActionCable. Nearly everything this product does is
  # long-running and asynchronous — syncs, analysis steps, backfills, runs — so
  # the browser subscribes to progress rather than polling for it.
  use GraphQL::Subscriptions::ActionCableSubscriptions

  # For batch-loading (see https://graphql-ruby.org/dataloader/overview.html)
  use GraphQL::Dataloader

  def self.type_error(err, context)
    super
  end

  def self.resolve_type(abstract_type, obj, ctx)
    case obj
    when Thing then Types::ThingType
    when Tenant then Types::TenantType
    else
      raise GraphQL::RequiredImplementationMissingError, "No GraphQL type for #{obj.class}"
    end
  end

  max_depth(15)
  max_query_string_tokens(5000)
  validate_max_errors(100)

  def self.id_from_object(object, type_definition, query_ctx)
    object.to_gid_param
  end

  # A global id names a class and a primary key, and nothing else. Resolving one
  # without re-checking the tenant is a cross-tenant read that looks like an
  # ordinary lookup — `node(id:)` walks straight out of the tenant.
  #
  # Default scopes already narrow this, but the check is explicit because the
  # failure is silent and the cost is one comparison.
  def self.object_from_id(global_id, query_ctx)
    # An id belonging to another tenant is invisible rather than forbidden —
    # row-level security makes the lookup miss, and a miss is not an error.
    record = begin
      GlobalID.find(global_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
    return nil if record.nil?

    tenant = query_ctx[:tenant]
    return nil if tenant.nil?
    return nil if record.respond_to?(:tenant_id) && record.tenant_id != tenant.id

    record
  end
end
