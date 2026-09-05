class Item < ApplicationRecord
  include TenantScoped

  has_many :references, -> { oldest_first }, class_name: "Reference", dependent: :destroy,
                                             inverse_of: :item
  has_many :resources, through: :references

  belongs_to :parent, class_name: "Item", optional: true
  has_many :children, -> { order(:id) }, class_name: "Item", foreign_key: :parent_id,
                                         inverse_of: :parent, dependent: :destroy

  validates :kind, presence: true

  after_commit :index_for_search, on: [ :create, :update ]
  after_commit :remove_from_search, on: :destroy

  def self.search(query, kind: nil, limit: 50)
    ids = SearchIndex.search(query, kind: kind, limit: limit)
    return none if ids.empty?

    where(id: ids).in_order_of(:id, ids)
  end

  def self.referencing(resource_id)
    where(id: Reference.where(resource_id: resource_id).select(:item_id))
  end

  def self.referenced
    where(id: Reference.select(:item_id))
  end

  SELECTOR = %w[id kind resource_id query folder since before].freeze

  def self.under(folder)
    prefix = folder.to_s.delete_prefix("/").chomp("/")
    return all if prefix.empty?

    where(id: Reference.under(prefix).select(:item_id))
  end

  def self.matching(selector)
    selector = selector.to_h.with_indifferent_access
    scope = all
    scope = scope.where(id: selector[:id]) if selector[:id].present?
    scope = scope.where(kind: selector[:kind]) if selector[:kind].present?
    scope = scope.referencing(selector[:resource_id]) if selector[:resource_id].present?
    scope = scope.under(selector[:folder]) if selector[:folder].present?
    scope = scope.where(created_at: moment(selector[:since])..) if selector[:since].present?
    scope = scope.where(created_at: ...moment(selector[:before])) if selector[:before].present?
    scope = scope.where(id: search(selector[:query]).ids) if selector[:query].present?
    scope
  end

  def self.moment(value)
    return value if value.respond_to?(:to_time) && !value.is_a?(String)

    Time.zone.parse(value.to_s) || raise(ArgumentError, "#{value} is not a date")
  rescue ArgumentError, TypeError
    raise ArgumentError, "#{value} is not a date"
  end

  def merge!(other)
    raise ArgumentError, "an item cannot merge into itself" if other.id == id

    transaction do
      other.references.to_a.each { |reference| reference.move_to!(self) }
      references.reset
    end

    self
  end

  def destroy_if_empty!
    destroy! if references.empty?
  end

  def reference
    references.first
  end

  def resource
    reference&.resource
  end

  def locator
    reference&.locator || {}
  end

  def locator_key
    reference&.locator_key
  end

  def referenced_by?(resource)
    references.any? { |reference| reference.resource_id == resource.id }
  end

  def source_for(destination)
    references.find { |reference| reference.resource_id != destination.id }
  end

  def copy_at(destination)
    references.find { |reference| reference.resource_id == destination.id }
  end

  def download
    raise ArgumentError, "no reference" if reference.nil?

    reference.download
  end

  def export_path
    reference&.path || id.to_s
  end

  def analyzed_at
    references.filter_map(&:analyzed_at).max
  end

  def analyze!
    Run.start!(kind: "analyze", selector: { "id" => id }).tap do |run|
      AnalyzeItemsJob.perform_later(tenant_id, { "id" => id }, run.id)
    end
  end

  def announce_analyzed!
    Tenant.switch(tenant) do
      UrisSchema.subscriptions.trigger(:item_analyzed, {}, self, scope: tenant_id)
      UrisSchema.subscriptions.trigger(:item_analyzed, { id: to_gid_param }, self,
                                         scope: tenant_id)
    end
  end

  def body_text
    strings = []
    collect_strings(references.flat_map(&:extracted)) { |s| strings << s }
    children.each { |child| collect_strings(child.references.flat_map(&:extracted)) { |s| strings << s } }
    strings.uniq.join("\n").presence
  end

  DEPTH = 4

  def depth
    held = 0
    node = self

    while (node = node.parent) && held < DEPTH
      held += 1
    end

    held
  end

  def children_ready?
    children.all? { |child| child.analyzed_at.present? }
  end

  private

    def index_for_search
      Tenant.switch(Tenant.find(tenant_id)) { SearchIndex.index(self) }
    end

    def remove_from_search
      SearchIndex.delete(self)
    end

    def collect_strings(value, &block)
      case value
      when String then yield value if value.length > 1
      when Array then value.each { |v| collect_strings(v, &block) }
      when Hash then value.each_value { |v| collect_strings(v, &block) }
      end
    end
end
