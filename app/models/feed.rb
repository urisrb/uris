class Feed < ApplicationRecord
  include TenantScoped

  TURNS = 6
  MINIMUM_INTERVAL = 1.minute

  # A slug becomes a path, so it cannot be a name the application already answers to.
  # Route order alone would not say which of the two wins.
  # Kept honest by a test that walks the route table, so a new route cannot
  # quietly become a slug someone can claim.
  RESERVED = %w[
    mcp graphql graphiql auth enroll references items resources runs settings
    jobs up assets vite feeds rails cable audit merges uploads
    recede resume refresh
  ].freeze

  SLUG = /\A[a-z0-9][a-z0-9-]{0,62}\z/

  has_many :runs, dependent: :nullify
  has_many :feed_items, dependent: :destroy
  has_many :items, through: :feed_items
  has_many :minted_items, -> { minted }, class_name: "Item", dependent: :nullify,
                                         inverse_of: :feed

  validates :slug, presence: true, format: { with: SLUG, message: "is letters, numbers and dashes" },
                   uniqueness: { scope: :tenant_id }
  validates :prompt, presence: true
  validates :role, presence: true
  validate :the_slug_is_not_spoken_for

  validates :interval, numericality: { greater_than_or_equal_to: MINIMUM_INTERVAL.to_i },
                       allow_nil: true

  scope :by_slug, ->(slug) { where(slug: slug.to_s.downcase) }
  scope :scheduled, -> { where.not(interval: nil).where(paused_at: nil) }
  scope :due, -> { scheduled.where(next_run_at: ..Time.current) }

  def turns_allowed
    turns.presence || TURNS
  end

  def to_param = slug

  def run!
    Run.start!(kind: "feed", feed: self).tap do |run|
      schedule_next!
      RunFeedJob.perform_later(tenant_id, id, run.id)
    end
  end

  def scheduled? = interval.present? && paused_at.nil?

  def paused? = paused_at.present?

  def pause! = update!(paused_at: Time.current, next_run_at: nil)

  def resume! = update!(paused_at: nil).then { schedule_next! }

  # Counted from now rather than from when the last run finished, so a slow feed does not
  # drift its own schedule later every time.
  def schedule_next!
    return if interval.blank? || paused?

    update_columns(next_run_at: Time.current + interval.seconds)
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
