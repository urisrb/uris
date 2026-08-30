class Resource < ApplicationRecord
  class Failed < StandardError; end

  include TenantScoped

  serialize :credentials, coder: JSON, type: Hash
  encrypts :credentials

  has_many :things, dependent: :nullify

  validates :key, presence: true,
                  uniqueness: { scope: [ :tenant_id, :type ], case_sensitive: true }

  scope :active, -> { where(archived_at: nil) }

  class << self
    def sti_name
      return super if self == Resource

      name.demodulize.underscore.dasherize
    end

    def find_sti_class(type_name)
      return super if type_name.include?("::")

      const_get("Resource::#{type_name.tr('-', '_').camelize}")
    end

    def capabilities
      []
    end

    def command_schema
      {}
    end
  end

  def capabilities
    self.class.capabilities
  end

  def storage?
    capabilities.include?(:storage)
  end

  def storage!
    raise ArgumentError, "#{key} is not storage — it cannot be an export destination" unless storage?

    self
  end

  def describe
    {
      type: self.class.sti_name,
      key: key,
      name: name,
      capabilities: capabilities,
      commands: self.class.command_schema
    }
  end

  def check!
    raise NotImplementedError, "#{self.class} does not implement #check!"
  end

  def command(name, arguments = {})
    schema = self.class.command_schema[name.to_s.to_sym]
    raise ArgumentError, "#{self.class.sti_name} has no command '#{name}'" if schema.nil?

    given = arguments.to_h.symbolize_keys.slice(*schema.keys)
    missing = schema.reject { |_, type| type.end_with?("?") }.keys - given.keys
    raise ArgumentError, "'#{name}' requires #{missing.join(', ')}" if missing.any?

    public_send(:"command_#{name}", **given)
  end

  def syncable?
    respond_to?(:each_page)
  end

  def sync!
    raise ArgumentError, "#{self.class.sti_name} is not syncable" unless syncable?

    SyncResourceJob.perform_later(tenant_id, id)
  end
end
