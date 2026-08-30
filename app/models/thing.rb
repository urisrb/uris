class Thing < ApplicationRecord
  include TenantScoped

  belongs_to :resource, optional: true

  validates :kind, presence: true

  def self.upsert_reference!(resource:, locator:, locator_key:, kind:, title: nil)
    thing = find_or_initialize_by(resource: resource, locator_key: locator_key)
    thing.assign_attributes(locator: locator, kind: kind, title: title)
    thing.save!
    thing
  end
end
