class MergeProposal < ApplicationRecord
  include TenantScoped

  class Stale < StandardError; end

  STATUSES = %w[open accepted rejected stale].freeze
  REASONS = %w[same-name same-bytes].freeze

  validates :blocking_key, :reason, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: "open") }
  scope :newest_first, -> { order(id: :desc) }

  def things
    Thing.where(id: thing_ids).order(:created_at, :id)
  end

  # A proposal is a reading of the catalog at a moment, and the catalog moves.
  # Accepting one whose things have since been merged away would either fail
  # loudly or merge the wrong pair, so it is checked first and retired if the
  # ground has shifted.
  def current?
    things.count == thing_ids.length
  end

  def accept!
    raise Stale, "the things this proposal named are no longer all there" unless current?

    held = things.to_a
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
