module TrackedRun
  extend ActiveSupport::Concern

  CHECK_EVERY = 50

  included do
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

  # The only way to stop a run that holds no token: a flag the iteration reads,
  # rather than a signal something delivers. Checked on the same beat progress
  # is flushed, so a hundred thousand objects cost two thousand queries and not
  # two hundred thousand.
  def track_iteration
    @seen = @seen.to_i + 1
    @pending_progress = @pending_progress.to_i + 1

    return unless @seen == 1 || (@seen % CHECK_EVERY).zero?

    flush_run_progress
    throw(:abort) if halted?
  end

  def halted?
    return false if run.nil?

    Tenant.switch(run.tenant) { run.halted? }
  end

  def fail_run(error)
    return if run.nil?

    flush_run_progress
    Tenant.switch(run.tenant) { run.finished!(error: "#{error.class}: #{error.message}") }
  end

  private

    def run
      return @run if defined?(@run)

      @run = Tenant.switch(Tenant.find(arguments.first)) { Run.find_by(id: run_id) }
    end

    def run_started
      Tenant.switch(run.tenant) { run.running! } if run
    end

    def flush_run_progress
      return if run.nil? || @pending_progress.to_i.zero?

      Tenant.switch(run.tenant) { run.progressed!(@pending_progress) }
      @pending_progress = 0
    end

    def run_finished
      return if run.nil?

      flush_run_progress
      Tenant.switch(run.tenant) { run.finished! }
    end
end
