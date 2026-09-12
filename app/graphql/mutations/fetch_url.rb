# frozen_string_literal: true

module Mutations
  class FetchUrl < BaseMutation
    argument :url, String, required: true

    field :run, Types::RunType, null: false

    def resolve(url:)
      address = PublicAddress.permitted!(url)

      refused("there is no storage to keep it in — attach one on Resources") unless Resource.stores.exists?

      { run: FetchUrlJob.start!(Current.tenant.id, address.to_s) }
    rescue PublicAddress::Blocked, PublicAddress::Unresolvable => e
      refused(e.message)
    end
  end
end
