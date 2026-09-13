class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :grant, :audit, :credentials, :issuer, :origin, :acting_for, :confined_to

  def audit
    attributes[:audit] || {}
  end
end
