class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :grant, :audit, :credentials, :issuer, :origin

  def audit
    attributes[:audit] || {}
  end
end
