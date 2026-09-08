class MergeProposal < ApplicationRecord
  include TenantScoped

  class Stale < StandardError; end

  STATUSES = %w[open accepted rejected stale].freeze
  REASONS = %w[same-name same-bytes].freeze

  validates :blocking_key, :reason, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: "open") }
  scope :newest_first, -> { order(id: :desc) }

  def feeds
    Feed.where(id: feed_ids).order(:created_at, :id)
  end

  def current?
    feeds.count == feed_ids.length
  end

  def accept!
    raise Stale, "the feeds this proposal named are no longer all there" unless current?

    held = feeds.to_a
    into = held.first

    transaction do
      held.drop(1).each { |other| into.merge!(other) }
      settle!("accepted")
    end

    into
  end

  def reject!
    settle!("rejected")
  end

  def settle!(status)
    update!(status: status, settled_at: Time.current)
  end
end
