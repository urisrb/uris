class Feed < ApplicationRecord
  include TenantScoped

  TURNS = 6

  # A slug becomes a path, so it cannot be a name the application already answers to.
  # Route order alone would not say which of the two wins.
  RESERVED = %w[
    mcp graphql graphiql auth enroll references items resources runs settings
    jobs up assets vite feeds rails cable
  ].freeze

  SLUG = /\A[a-z0-9][a-z0-9-]{0,62}\z/

  has_many :runs, dependent: :nullify

  validates :slug, presence: true, format: { with: SLUG, message: "is letters, numbers and dashes" },
                   uniqueness: { scope: :tenant_id }
  validates :prompt, presence: true
  validates :role, presence: true
  validate :the_slug_is_not_spoken_for

  scope :by_slug, ->(slug) { where(slug: slug.to_s.downcase) }

  def turns_allowed
    turns.presence || TURNS
  end

  def to_param = slug

  def run!
    Run.start!(kind: "feed", feed: self).tap do |run|
      RunFeedJob.perform_later(tenant_id, id, run.id)
    end
  end

  # A feed acts as itself, with the scopes its own tenant grants. It never borrows the
  # token of whoever happened to open the page.
  def grant
    Grant.new(
      tenant: tenant,
      claims: Masks::Client::Claims.new(
        "sub" => "feed:#{slug}",
        "scope" => Grant::SIGN_IN.join(" "),
        "tenant" => { "subdomain" => tenant.subdomain }
      )
    )
  end

  private

    def the_slug_is_not_spoken_for
      return unless RESERVED.include?(slug.to_s.downcase)

      errors.add(:slug, "is a path uris already answers to")
    end
end
