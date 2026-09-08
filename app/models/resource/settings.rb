class Resource
  class Settings
    class Missing < ArgumentError; end
    class Unattachable < ArgumentError; end

    def self.for(klass, given)
      new(klass, given).settle
    end

    def initialize(klass, given)
      @klass = klass
      @given = given.to_h.stringify_keys

      raise Unattachable, "#{klass.sti_name} is not a type that can be attached" if fields.nil?
    end

    def settle
      details = {}
      credentials = {}

      fields.each do |field|
        raw = offered(field)

        if blank?(raw)
          raise Missing, "#{field[:label]} is needed" if field[:required]

          next
        end

        place(field[:held] == :credentials ? credentials : details, field[:name],
              cast(raw, field[:kind]))
      end

      [ details, credentials ]
    end

    def named
      fields.map { |field| field[:name] }
    end

    private

      def fields
        return @fields if defined?(@fields)

        @fields = @klass.attaching&.fetch(:fields)
      end

      def offered(field)
        held = @given[field[:name]]

        blank?(held) ? field[:value] : held
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
  end
end
