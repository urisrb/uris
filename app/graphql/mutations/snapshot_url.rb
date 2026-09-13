# frozen_string_literal: true

module Mutations
  class SnapshotUrl < BaseMutation
    argument :url, String, required: true

    field :run, Types::RunType, null: false

    def resolve(url:)
      address = PublicAddress.permitted!(url)
      resource = Resource.browser(context[:grant])

      refused("nothing here can render a page — attach a web resource first") if resource.nil?

      { run: SnapshotUrlJob.start!(resource.tenant_id, resource, address.to_s) }
    rescue PublicAddress::Blocked, PublicAddress::Unresolvable => e
      refused(e.message)
    end
  end
end
