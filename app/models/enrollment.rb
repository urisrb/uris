class Enrollment
  class Invalid < StandardError; end

  PURPOSE = "enrollment".freeze
  WINDOW = 30.minutes

  ATTRIBUTES = %w[tenant_id type key name details].freeze

  attr_reader :tenant_id, :type, :key, :name, :details

  class << self
    def open!(type:, key:, name: nil, details: {})
      klass = Resource.find_sti_class(type.to_s)

      raise ArgumentError, "#{type} is not enrolled through the browser" unless klass.respond_to?(:broker_provider)

      new(
        tenant_id: Current.tenant.id,
        type: type.to_s,
        key: key.to_s,
        name: name.presence || key.to_s,
        details: details || {}
      )
    rescue NameError
      raise ArgumentError, "there is no resource type named #{type}"
    end

    def redeem(token)
      payload = verifier.verify(token.to_s, purpose: PURPOSE)

      new(**payload.slice(*ATTRIBUTES).symbolize_keys)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, TypeError
      raise Invalid, "that enrollment link is not valid, or has expired"
    end

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end

  def initialize(tenant_id:, type:, key:, name: nil, details: {})
    @tenant_id = tenant_id
    @type = type
    @key = key
    @name = name
    @details = details || {}
  end

  def resource_class
    Resource.find_sti_class(type)
  end

  def provider
    resource_class.broker_provider
  end

  def token
    self.class.verifier.generate(
      {
        "tenant_id" => tenant_id, "type" => type, "key" => key,
        "name" => name, "details" => details
      },
      purpose: PURPOSE,
      expires_in: WINDOW
    )
  end

  def url(origin)
    "#{origin}/enroll/#{token}"
  end

  def belongs_to?(tenant)
    tenant_id == tenant.id
  end

  def claim!(connection_id)
    resource = resource_class.find_or_initialize_by(key: key)

    resource.name = name
    resource.details = resource.details.merge(details)
    resource.connection_id = connection_id
    resource.save!

    resource
  end
end
