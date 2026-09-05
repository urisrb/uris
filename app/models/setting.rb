class Setting < ApplicationRecord
  include TenantScoped

  class Unknown < StandardError; end

  LEVELS = %i[personal server].freeze

  Definition = Data.define(:key, :level, :default, :allowed, :label, :note) do
    def personal? = level == :personal
    def server? = level == :server
    def permits?(value) = allowed.include?(value)
    def reads = personal? ? "things:settings:read" : "things:settings:admin"
    def writes = personal? ? "things:settings:write" : "things:settings:admin"
  end

  DEFINED = [
    Definition.new(
      key: "catalog_view",
      level: :personal,
      default: "list",
      allowed: %w[list cards],
      label: "How the catalog opens",
      note: "A list reads names quickly. Cards show you what a thing looks like."
    )
  ].index_by(&:key).freeze

  validates :key, inclusion: { in: DEFINED.keys }
  validate :value_is_one_the_definition_allows

  def self.definition!(key)
    DEFINED[key.to_s] || raise(Unknown, "no setting named #{key}")
  end

  def self.at(level)
    DEFINED.values.select { |definition| definition.level == level }
  end

  def self.read(key, subject:)
    definition = definition!(key)

    owned(definition, subject).find_by(key: definition.key)&.value || definition.default
  end

  def self.write!(key, value, subject:)
    definition = definition!(key)
    record = owned(definition, subject).find_or_initialize_by(key: definition.key)

    record.update!(value: value)
    record
  end

  def self.owned(definition, subject)
    where(subject: definition.personal? ? subject : nil)
  end

  def definition
    DEFINED[key]
  end

  private

    def value_is_one_the_definition_allows
      return if definition.nil? || definition.permits?(value)

      errors.add(:value, "is not one of #{definition.allowed.join(', ')}")
    end
end
