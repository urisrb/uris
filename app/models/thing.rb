# A reference to something you own, wherever it lives. The bytes stay in the
# resource; this row holds the locator, the extracted metadata, and the
# analysis.
#
# `kind` is what a thing IS — pdf, email, image — and decides how it is
# understood. Not to be confused with a resource's `type`, which is the dialect
# its resource speaks.
class Thing < ApplicationRecord
  include TenantScoped

  validates :kind, presence: true
end
