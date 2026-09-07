module Gated
  extend ActiveSupport::Concern

  module Enumeration
    def build_enumerator(*args, cursor:, **rest)
      return refuse_gated_run if gate.closed?

      super
    end
  end

  included do
    prepend Enumeration
  end

  class_methods do
    def gated_as(key, enabled: true, live: true)
      @gate_key = key
      @gate_defaults = { enabled: enabled, live: live }
    end

    def gate_key
      @gate_key || name
    end

    def gate_defaults
      @gate_defaults || { enabled: true, live: true }
    end
  end

  def gate
    @gate ||= read_gate
  end

  def refresh_gate
    @gate = read_gate
  end

  def dry_run?
    gate.dry_run?
  end

  def gate_reference
    nil
  end

  private

    def refuse_gated_run
      mark_run_gated
      enumerator_builder.build_array_enumerator([], cursor: nil)
    end

    def read_gate
      return Gate::Decision.new(**self.class.gate_defaults) if Current.tenant.nil?

      Gate.decide(key: self.class.gate_key, reference: gate_reference, **self.class.gate_defaults)
    end

    def mark_run_gated
      run&.gated!
    end

    def halt_for_gate!
      mark_run_gated

      throw(:abort)
    end
end
