class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :grant, :audit

  def audit
    attributes[:audit] || {}
  end
end
