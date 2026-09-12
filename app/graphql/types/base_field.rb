# frozen_string_literal: true

module Types
  class BaseField < GraphQL::Schema::Field
    argument_class Types::BaseArgument

    def initialize(*args, grants: nil, **kwargs, &block)
      @grants = Array(grants).map(&:to_s).presence

      super(*args, **kwargs, &block)
    end

    def grants
      @grants || []
    end

    def authorized?(object, args, context)
      return false unless super

      permit!(context)
    end

    private

      def permit!(context)
        return true if @grants.nil?

        grant = context[:grant]

        raise GraphQL::ExecutionError, "this token carries no grant" if grant.nil?
        return true if @grants.any? { |scope| grant.permits?(scope) }

        raise GraphQL::ExecutionError, "this token does not carry #{@grants.join(' or ')}"
      end
  end
end
