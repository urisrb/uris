class Run < ApplicationRecord
  class Cancelled < StandardError; end

  include TenantScoped

  KINDS = %w[sync export analyze].freeze
  STATUSES = %w[queued running done failed cancelled gated].freeze
  OPEN = %w[queued running].freeze

  belongs_to :resource, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: OPEN) }
  scope :newest_first, -> { order(id: :desc) }

  def self.start!(kind:, resource: nil, selector: {}, deadline: nil)
    create!(kind: kind, resource: resource, selector: selector.to_h, deadline: deadline)
  end

  def open?
    OPEN.include?(status)
  end

  # Conditional on still being open, or a job picked up after its run was
  # cancelled would resurrect it and then finish it as done.
  def running!
    Run.where(id: id, status: OPEN)
       .update_all(status: "running", started_at: started_at || Time.current)
  end

  def progressed!(count)
    return if count.zero?

    Run.where(id: id).update_all("processed = processed + #{count.to_i}")
  end

  def finished!(error: nil)
    return if %w[cancelled gated].include?(current_status)

    update_columns(
      status: error ? "failed" : "done",
      error: error&.truncate(500),
      finished_at: Time.current
    )
  end

  # A gate closing is not a failure and not a cancellation — nobody asked for
  # it to stop, and it should read differently in a list of runs.
  def gated!
    return false unless open?

    update_columns(status: "gated", finished_at: Time.current)
    true
  end

  def cancel!
    return false unless open?

    update_columns(status: "cancelled", finished_at: Time.current)
    true
  end

  # Cheap enough to run every few iterations, which is the only way a run with
  # no token can be stopped: it is a flag the iteration checks, not a signal
  # anything can deliver. A row that has gone away halts too — there is nothing
  # left to report progress to.
  def halted?
    fresh = current_status
    return true if fresh.nil?

    self.status = fresh
    return true if fresh == "cancelled"

    expired?
  end

  def expired?
    return false if deadline.nil?
    return false if Time.current < deadline

    update_columns(status: "cancelled", error: "deadline passed", finished_at: Time.current)
    true
  end

  private

    def current_status
      Run.where(id: id).pick(:status)
    end
end
