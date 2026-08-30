class ResourceBlob < ApplicationRecord
  include TenantScoped

  belongs_to :resource

  validates :key, presence: true, uniqueness: { scope: [ :tenant_id, :resource_id ] }

  def size
    bytes.bytesize
  end
end
