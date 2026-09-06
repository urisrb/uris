class FeedItem < ApplicationRecord
  include TenantScoped

  belongs_to :feed
  belongs_to :item
  belongs_to :run, optional: true

  validates :item_id, uniqueness: { scope: [ :tenant_id, :feed_id ] }
end
