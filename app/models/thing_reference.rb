class ThingReference < ApplicationRecord
  include TenantScoped

  belongs_to :thing
  belongs_to :resource

  validates :locator_key, uniqueness: { scope: [ :tenant_id, :resource_id ] }, allow_nil: true

  scope :oldest_first, -> { order(:created_at, :id) }

  after_commit :reindex_thing

  delegate :kind, to: :thing

  def self.discover!(resource:, locator:, locator_key:, kind:, title: nil)
    reference = find_or_initialize_by(resource: resource, locator_key: locator_key)

    if reference.thing.nil?
      reference.thing = Thing.create!(kind: kind, title: title)
    end

    reference.update!(locator: locator)
    reference
  end

  def move_to!(destination)
    return self if destination.id == thing_id

    previous = thing

    transaction do
      if destination.references.exists?(resource_id: resource_id, locator_key: locator_key)
        destroy!
      else
        update!(thing: destination)
      end

      previous.reload.destroy_if_empty!
    end

    self
  end

  def split!
    move_to!(Thing.create!(kind: thing.kind, title: thing.title))
  end

  def download
    resource.download(locator)
  end

  def path
    [ resource.key, locator_key ].compact.join("/")
  end

  def extracted
    analysis.fetch("steps", {}).values.filter_map { |step| step["result"] }
  end

  private

    def reindex_thing
      Tenant.switch(Tenant.find(tenant_id)) do
        subject = Thing.find_by(id: thing_id)
        SearchIndex.index(subject) if subject
      end
    end
end
