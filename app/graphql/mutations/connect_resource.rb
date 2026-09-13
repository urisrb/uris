# frozen_string_literal: true

module Mutations
  class ConnectResource < BaseMutation
    argument :id, ID, required: true

    field :url, String, null: false,
          description: "Open it in the browser. It goes through masks and comes back connected."

    def resolve(id:)
      resource = resource!(id)

      refused("#{resource.key} is not connected through masks") unless resource.delegated?

      { url: Rails.application.routes.url_helpers.resource_connect_path(resource) }
    end
  end
end
