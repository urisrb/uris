class Resource < ApplicationRecord
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

  def syncable?
    respond_to?(:each_page)
  end

  def sync!
    raise ArgumentError, "#{self.class.sti_name} is not syncable" unless syncable?

    SyncResourceJob.perform_later(tenant_id, id)
  end
end
