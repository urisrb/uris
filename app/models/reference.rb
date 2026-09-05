class Reference < ApplicationRecord
  # "references" is a reserved word in Postgres.
  self.table_name = "item_references"

  include TenantScoped

  belongs_to :item
  belongs_to :resource

  validates :locator_key, uniqueness: { scope: [ :tenant_id, :resource_id ] }, allow_nil: true

  scope :oldest_first, -> { order(:created_at, :id) }

  scope :under, ->(prefix) {
    escaped = sanitize_sql_like(prefix.to_s.delete_prefix("/").chomp("/"))

    where("locator_key = :exact OR locator_key LIKE :under ESCAPE '\\'",
          exact: prefix, under: "#{escaped}/%")
  }

  after_commit :reindex_thing

  delegate :kind, to: :item

  def self.discover!(resource:, locator:, locator_key:, kind:, title: nil)
    reference = find_or_initialize_by(resource: resource, locator_key: locator_key)

    if reference.item.nil?
      reference.item = Item.create!(kind: kind, title: title)
    end

    reference.locator = locator
    reference.note_version!(resource.version_for(locator))
    reference.save!
    reference
  end

  def self.record!(item:, resource:, locator:, locator_key:, source_version: nil)
    reference = find_or_initialize_by(resource: resource, locator_key: locator_key)

    if reference.persisted? && reference.item_id != item.id
      reference.move_to!(item)
    else
      reference.item = item
    end

    reference.locator = locator
    reference.version = resource.version_for(locator)
    reference.source_version = source_version
    reference.save!
    reference
  end

  def note_version!(reported)
    return self if reported.blank?

    if version.present? && version != reported
      self.changed_at = Time.current
      self.analyzed_at = nil
    end

    self.version = reported
    self
  end

  def stale_against?(source)
    source_version.present? && source.version.present? && source_version != source.version
  end

  def move_to!(destination)
    return self if destination.id == item_id

    previous = item

    transaction do
      if destination.references.exists?(resource_id: resource_id, locator_key: locator_key)
        destroy!
      else
        update!(item: destination)
      end

      previous.reload.destroy_if_empty!
    end

    self
  end

  def split!
    move_to!(Item.create!(kind: item.kind, title: item.title))
  end

  def download
    resource.download(locator)
  end

  def path
    [ resource.key, locator_key ].compact.join("/")
  end

  def filename
    File.basename(locator_key.to_s).presence || "item-#{item_id}"
  end

  def content_type
    Rack::Mime.mime_type(File.extname(filename), "application/octet-stream")
  end

  def thumbnail?
    Thumbnail.available_for?(kind)
  end

  def extracted
    analysis.fetch("steps", {}).values.filter_map { |step| step["result"] }
  end

  private

    def reindex_thing
      Tenant.switch(Tenant.find(tenant_id)) do
        subject = Item.find_by(id: item_id)
        SearchIndex.index(subject) if subject
      end
    end
end
