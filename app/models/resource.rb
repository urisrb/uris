class Resource < ApplicationRecord
  class Failed < StandardError; end
  class Unusable < Failed; end

  include TenantScoped

  serialize :credentials, coder: JSON, type: Hash
  encrypts :credentials

  has_many :items, dependent: :nullify
  has_many :prompts, dependent: :destroy

  belongs_to :via, class_name: "Resource", optional: true
  has_many :reached_through, class_name: "Resource", foreign_key: :via_id,
                             inverse_of: :via, dependent: :restrict_with_error

  MINIMUM_SYNC_INTERVAL = 1.minute
  SYNC_ABANDONED_AFTER = 6.hours
  MAX_HOPS = 4
  DEFAULTABLE = { storage: :default_storage, inference: :default_inference }.freeze

  TYPES = %w[
    s3 filesystem webdav caldav carddav imap rss web openai-compatible oauth-google database
    search mcp
  ].freeze

  validates :key, presence: true,
                  uniqueness: { scope: [ :tenant_id, :type ], case_sensitive: true }
  validates :sync_interval, numericality: {
    greater_than_or_equal_to: MINIMUM_SYNC_INTERVAL.to_i
  }, allow_nil: true
  validate :only_a_syncable_resource_keeps_a_schedule
  validate :a_default_is_a_resource_that_can_be_one
  validate :via_is_a_transport
  validate :via_is_this_tenants
  validate :via_leads_somewhere
  validate :a_transport_in_use_is_not_archived

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

    # What a type needs before it can answer, declared rather than written down,
    # so a form is rendered from the type instead of kept in step with it. Nil
    # means a type nobody attaches by hand.
    def attaching
      nil
    end

    def attachable
      TYPES.filter_map do |name|
        held = find_sti_class(name)

        held if held.attaching.present?
      end
    end

    def brokered?
      false
    end

    def field(name, label, kind: "string", required: false, secret: false, held: nil,
              value: nil, help: nil, placeholder: nil)
      {
        name: name, label: label, kind: kind, required: required, secret: secret,
        held: held || (secret ? :credentials : :details),
        value: value, help: help, placeholder: placeholder
      }
    end

    def capable_of(capability)
      active.select { |resource| resource.capabilities.include?(capability) }
    end

    def browser
      capable_of(:browser).first
    end

    def browser!
      browser || raise(ArgumentError, "this tenant has nothing that can render a page")
    end

    def default_for(capability)
      active.find_by(DEFAULTABLE.fetch(capability) => true)
    end

    def default_for!(capability)
      default_for(capability) ||
        raise(ArgumentError, "this tenant has no default #{capability} resource")
    end

    def default_storage = default_for(:storage)
    def default_storage! = default_for!(:storage)
    def default_inference = default_for(:inference)
    def default_inference! = default_for!(:inference)

    def for_role(role)
      candidates = active.select { |resource| resource.inference? && resource.serves_role?(role) }

      candidates.find(&:default_inference?) || candidates.first
    end
  end

  def capabilities
    self.class.capabilities
  end

  def storage?
    capabilities.include?(:storage)
  end

  def inference?
    capabilities.include?(:inference)
  end

  def transport?
    capabilities.include?(:transport)
  end

  def storage!
    raise ArgumentError, "#{key} is not storage — it cannot be an export destination" unless storage?

    self
  end

  def serves_role?(_role)
    false
  end

  def reach!(_target)
    raise NotImplementedError, "#{self.class.sti_name} is not a transport"
  end

  def make_default_for!(capability)
    column = DEFAULTABLE.fetch(capability)

    unless capabilities.include?(capability)
      raise ArgumentError, "#{key} is not #{capability} — it cannot be the default"
    end

    transaction do
      Resource.where(column => true).where.not(id: id).update_all(column => false)
      update!(column => true)
    end

    self
  end

  def make_default_storage! = make_default_for!(:storage)
  def make_default_inference! = make_default_for!(:inference)

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

  def version_for(locator)
    locator.to_h["etag"].presence
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

    def a_default_is_a_resource_that_can_be_one
      DEFAULTABLE.each do |capability, column|
        next unless public_send(:"#{column}?")
        next if capabilities.include?(capability)

        errors.add(column, "cannot be set on #{self.class.sti_name}, which is not #{capability}")
      end
    end

    def via_is_a_transport
      return if via.nil? || via.transport?

      errors.add(:via, "#{via.key} is not a transport — nothing can be reached through it")
    end

    def via_is_this_tenants
      return if via_id.nil?
      return if via.present? && via.tenant_id == tenant_id

      errors.add(:via, "belongs to another tenant, or does not exist")
    end

    def via_leads_somewhere
      return if via_id.nil?

      if via_id == id
        errors.add(:via, "cannot be itself")
        return
      end

      seen = [ id ].compact
      node = via
      hops = 0

      while node
        if seen.include?(node.id)
          errors.add(:via, "would make a loop through #{node.key}")
          return
        end

        seen << node.id
        hops += 1

        if hops > MAX_HOPS
          errors.add(:via, "is more than #{MAX_HOPS} hops from anything that answers")
          return
        end

        node = node.via
      end
    end

    def a_transport_in_use_is_not_archived
      return unless persisted? && archived_at.present? && archived_at_changed?

      dependents = Resource.active.where(via_id: id).where.not(id: id).pluck(:key)
      return if dependents.empty?

      errors.add(:archived_at,
                 "cannot be set while #{dependents.to_sentence} #{dependents.one? ? 'is' : 'are'} reached through #{key}")
    end
end
