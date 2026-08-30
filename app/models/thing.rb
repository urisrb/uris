class Thing < ApplicationRecord
  include TenantScoped

  belongs_to :resource, optional: true

  validates :kind, presence: true

  after_commit :index_for_search, on: [ :create, :update ]
  after_commit :remove_from_search, on: :destroy

  def self.search(query, kind: nil, limit: 50)
    ids = SearchIndex.search(query, kind: kind, limit: limit)
    return none if ids.empty?

    where(id: ids).in_order_of(:id, ids)
  end

  def self.upsert_reference!(resource:, locator:, locator_key:, kind:, title: nil)
    thing = find_or_initialize_by(resource: resource, locator_key: locator_key)
    thing.assign_attributes(locator: locator, kind: kind, title: title)
    thing.save!
    thing
  end

  private

    def index_for_search
      SearchIndex.index(self)
    end

    def remove_from_search
      SearchIndex.delete(self)
    end
end
