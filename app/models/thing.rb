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

  def download
    raise ArgumentError, "no resource" if resource.nil?

    resource.download(locator)
  end

  def body_text
    strings = []
    results = analysis.fetch("steps", {}).values.map { |step| step["result"] }
    collect_strings(results) { |s| strings << s }
    strings.uniq.join("\n").presence
  end

  def analyze!
    AnalyzeThingJob.perform_later(tenant_id, id)
  end

  def export_path
    [ resource&.key, locator_key ].compact.join("/")
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

    def collect_strings(value, &block)
      case value
      when String then yield value if value.length > 1
      when Array then value.each { |v| collect_strings(v, &block) }
      when Hash then value.each_value { |v| collect_strings(v, &block) }
      end
    end
end
