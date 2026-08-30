class Resource < ApplicationRecord
  class Failed < StandardError; end

  include TenantScoped

  serialize :credentials, coder: JSON, type: Hash
  encrypts :credentials

  has_many :things, dependent: :nullify

  MINIMUM_SYNC_INTERVAL = 1.minute
  SYNC_ABANDONED_AFTER = 6.hours

  validates :key, presence: true,
                  uniqueness: { scope: [ :tenant_id, :type ], case_sensitive: true }
  validates :sync_interval, numericality: {
    greater_than_or_equal_to: MINIMUM_SYNC_INTERVAL.to_i
  }, allow_nil: true
  validate :only_a_syncable_resource_keeps_a_schedule
  validate :only_storage_can_be_the_default

  before_save :start_the_schedule, if: :sync_interval_changed?

  scope :active, -> { where(archived_at: nil) }
  scope :scheduled, -> { active.where.not(sync_interval: nil) }
  scope :not_syncing, -> {
    where(sync_started_at: nil).or(where(sync_started_at: ...SYNC_ABANDONED_AFTER.ago))
  }
  scope :due_for_sync, -> { scheduled.not_syncing.where(next_sync_at: ..Time.current) }

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

    def default_storage
      active.find_by(default_storage: true)
    end

    def default_storage!
      default_storage || raise(ArgumentError, "this tenant has no default storage resource")
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

  def make_default_storage!
    storage!

    transaction do
      Resource.where(default_storage: true).where.not(id: id).update_all(default_storage: false)
      update!(default_storage: true)
    end

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

  def check
    check!
    record_check(nil)
    true
  rescue NotImplementedError, StandardError => e
    record_check("#{e.class}: #{e.message}")
    false
  end

  def healthy?
    checked_at.present? && check_error.nil?
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

  def kind_for(object)
    Kind.for_filename(locator_key_for(object))
  end

  def title_for(object)
    File.basename(locator_key_for(object))
  end

  def syncing?
    sync_started_at.present? && sync_started_at > SYNC_ABANDONED_AFTER.ago
  end

  def sync!
    raise ArgumentError, "#{self.class.sti_name} is not syncable" unless syncable?
    return false unless claim_sync!

    Run.start!(kind: "sync", resource: self).tap do |run|
      SyncResourceJob.perform_later(tenant_id, id, run.id)
    end
  end

  def claim_sync!
    claimed = Resource.where(id: id).not_syncing.update_all(sync_started_at: Time.current)
    return false if claimed.zero?

    reload
    true
  end

  def release_sync!
    finished = Time.current

    update_columns(
      sync_started_at: nil,
      synced_at: finished,
      next_sync_at: sync_interval.present? ? next_sync_after(finished) : nil
    )
  end

  private

    def record_check(error)
      update_columns(checked_at: Time.current, check_error: error)
    end

    def next_sync_after(finished)
      anchor = next_sync_at || finished
      elapsed = ((finished - anchor) / sync_interval).floor + 1

      anchor + (elapsed * sync_interval)
    end

    def start_the_schedule
      self.next_sync_at = sync_interval.present? ? (next_sync_at || Time.current) : nil
    end

    def only_a_syncable_resource_keeps_a_schedule
      return if sync_interval.nil? || syncable?

      errors.add(:sync_interval, "cannot be set on #{self.class.sti_name}, which cannot sync")
    end

    def only_storage_can_be_the_default
      return if !default_storage? || storage?

      errors.add(:default_storage, "cannot be set on #{self.class.sti_name}, which is not storage")
    end
end
