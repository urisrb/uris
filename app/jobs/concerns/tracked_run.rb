module TrackedRun
  extend ActiveSupport::Concern

  CHECK_EVERY = 50

  included do
    include Gated

    on_start :run_started
    on_shutdown :flush_run_progress
    on_complete :run_finished

    rescue_from(StandardError) do |error|
      fail_run(error)
      raise error
    end
  end

  def run_id
    nil
  end

  def track_iteration(records = 1)
    @seen = @seen.to_i + 1
    @pending_progress = @pending_progress.to_i + records

    return unless @seen == 1 || (@seen % CHECK_EVERY).zero?

    flush_run_progress
    stop! if halted?
    halt_for_gate! if refresh_gate.closed?
  end

  def halted?
    return false if run.nil?

    run.halted?
  end

  def fail_run(error)
    return if run.nil?

    flush_run_progress
    run.finished!(error: "#{error.class}: #{error.message}")
  end

  private

    def run
      return @run if defined?(@run)

      @run = Run.find_by(id: run_id)
    end

    def run_started
      run&.running!
    end

    def flush_run_progress
      return if run.nil? || @pending_progress.to_i.zero?

      run.progressed!(@pending_progress)
      @pending_progress = 0
    end

    def run_finished
      return if run.nil?

      flush_run_progress
      run.finished!
    end
end
