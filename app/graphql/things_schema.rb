# frozen_string_literal: true

class ThingsSchema < GraphQL::Schema
  query(Types::QueryType)
  mutation(Types::MutationType)
  subscription(Types::SubscriptionType)

  use GraphQL::Subscriptions::ActionCableSubscriptions
  use GraphQL::Dataloader

  max_depth(15)
  max_query_string_tokens(5000)
  validate_max_errors(100)

  def self.resolve_type(abstract_type, obj, ctx)
    case obj
    when Thing then Types::ThingType
    when Resource then Types::ResourceType
    when Tenant then Types::TenantType
    else
      raise GraphQL::RequiredImplementationMissingError, "No GraphQL type for #{obj.class}"
    end
  end

  def self.id_from_object(object, type_definition, query_ctx)
    object.to_gid_param
  end

  def self.object_from_id(global_id, query_ctx)
    record = begin
      GlobalID.find(global_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    tenant = query_ctx[:tenant]
    return nil if record.nil? || tenant.nil?
    return nil if record.respond_to?(:tenant_id) && record.tenant_id != tenant.id

    record
  end
end
