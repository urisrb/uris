# frozen_string_literal: true

module Mutations
  class AttachResource < BaseMutation
    argument :type, String, required: true
    argument :key, String, required: true
    argument :name, String, required: false
    argument :settings, GraphQL::Types::JSON, required: false,
             description: "One entry per field the type declares. Anything else is dropped."

    field :resource, Types::ResourceType, null: false
    field :check_error, String, description: "What the first check said, if it did not pass."

    def resolve(type:, key:, name: nil, settings: nil)
      klass = attachable!(type)

      refused("#{type} is connected in the browser, not through a form") if klass.brokered?

      named = key.to_s.strip
      resource = klass.new(key: named, name: name.presence&.strip || named)

      settle(resource, klass.attaching[:fields], (settings || {}).to_h)

      refused(resource.errors.full_messages.to_sentence) unless resource.save

      noted(klass, resource, settings)
      resource.check

      { resource: resource, check_error: resource.check_error }
    end

    private

      def attachable!(type)
        klass = Resource.attachable.find { |held| held.sti_name == type.to_s }

        klass || refused("#{type} is not a type that can be attached")
      end

      # Only what the type declares is read, so a caller cannot smuggle a key the
      # form never offered into details or credentials.
      def settle(resource, fields, given)
        details = {}
        credentials = {}

        fields.each do |field|
          offered = given[field[:name]]
          raw = blank?(offered) ? field[:value] : offered

          if blank?(raw)
            refused("#{field[:label]} is needed") if field[:required]
            next
          end

          place(field[:held] == :credentials ? credentials : details, field[:name],
                cast(raw, field[:kind]))
        end

        resource.details = details
        resource.credentials = credentials
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:strip) && value.strip.empty?)
      end

      def place(held, name, value)
        steps = name.split(".")
        leaf = steps.pop

        steps.reduce(held) { |nest, step| nest[step] ||= {} }[leaf] = value
      end

      def cast(raw, kind)
        case kind
        when "integer" then raw.to_s.strip.to_i
        when "boolean" then ActiveModel::Type::Boolean.new.cast(raw)
        else raw.to_s.strip
        end
      end

      # The names of what was set, never the values — a credential does not belong
      # in the audit trail even redacted.
      def noted(klass, resource, settings)
        AuditEvent.record(
          channel: "graphql", action: "attach_resource", status: "ok",
          grant: context[:grant], context: { remote_ip: nil, request_id: nil },
          arguments: {
            "type" => klass.sti_name, "key" => resource.key,
            "set" => ((settings || {}).keys & klass.attaching[:fields].map { |f| f[:name] }).join(", ")
          }
        )
      end
  end
end
