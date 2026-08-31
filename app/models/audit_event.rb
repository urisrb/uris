class AuditEvent < ApplicationRecord
  include TenantScoped

  STATUSES = %w[ok error denied].freeze
  REDACTED = /secret|password|token|credential|authorization|access_key/i
  VALUE_LIMIT = 200
  DETAIL_LIMIT = 500

  belongs_to :run, optional: true

  validates :channel, :action, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :newest_first, -> { order(id: :desc) }

  class << self
    def record(channel:, action:, status:, grant: nil, context: {}, **attributes)
      create!(
        channel: channel.to_s,
        action: action.to_s,
        status: status.to_s,
        subject: grant&.subject,
        client_id: grant&.claims&.client_id,
        remote_ip: context[:remote_ip],
        request_id: context[:request_id],
        arguments: summarize(attributes[:arguments]),
        detail: attributes[:detail]&.to_s&.truncate(DETAIL_LIMIT),
        **attributes.except(:arguments, :detail)
      )
    end

    def summarize(arguments, depth: 0)
      return {} unless arguments.is_a?(Hash)

      arguments.each_with_object({}) do |(key, value), held|
        held[key.to_s] = REDACTED.match?(key.to_s) ? "[redacted]" : shorten(value, depth)
      end
    end

    private

      def shorten(value, depth)
        case value
        when Hash then depth.zero? ? summarize(value, depth: 1) : "{#{value.size} keys}"
        when Array then "[#{value.size} items]"
        when String then value.truncate(VALUE_LIMIT)
        when Numeric, TrueClass, FalseClass, NilClass then value
        else value.to_s.truncate(VALUE_LIMIT)
        end
      end
  end
end
