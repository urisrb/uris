require "test_helper"

class GraphqlGrantsTest < ActiveSupport::TestCase
  ROOTS = [ Types::QueryType, Types::MutationType, Types::SubscriptionType ].freeze

  REACHABLE = [ Types::FeedType, Types::ReferenceType, Types::AnalysisType,
                Types::ScheduleType, Types::ResourceType, Types::RunType,
                Types::MergeProposalType, Types::AuditEventType ].freeze

  def scopes_on(field)
    Array(field.instance_variable_get(:@grants))
  end

  test "every root field declares the scope it needs" do
    unguarded = ROOTS.flat_map do |type|
      type.fields.filter_map do |name, field|
        "#{type.graphql_name}.#{name}" if scopes_on(field).blank?
      end
    end

    assert_empty unguarded,
                 "add `grants:` to these, or a token with no scopes reaches them"
  end

  test "every scope a field asks for is one this app actually defines" do
    unknown = ROOTS.flat_map do |type|
      type.fields.flat_map { |_, field| scopes_on(field) } - Grant::SCOPES
    end

    assert_empty unknown.uniq, "a scope no token can carry refuses everyone"
  end

  test "every type carrying a record guards itself" do
    ungated = REACHABLE.reject { |type| type.grants.any? }

    assert_empty ungated.map(&:graphql_name),
                 "a type is reached through more than one field, so a field grant alone does not cover these"
  end

  test "a mutation is never satisfied by a read scope alone" do
    readable = Types::MutationType.fields.filter_map do |name, field|
      name if scopes_on(field).all? { |scope| scope.end_with?(":read") }
    end

    assert_empty readable, "a read scope must not drive a write"
  end
end
