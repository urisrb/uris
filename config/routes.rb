Rails.application.routes.draw do
  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  end

  # Two interfaces over one domain layer, and neither wraps the other:
  #
  #   /graphql   the browser. Session-authenticated, first-party client.
  #   /mcp       agents and remote clients. Typed tools, token-scoped grants.
  #
  # Exposing GraphQL *as* an MCP tool is what would collapse them back into
  # one — a single passthrough tool cannot be partially granted.
  post "/graphql", to: "graphql#execute"

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  # SPA catch-all — must stay last.
  get "*path", to: "home#index", constraints: ->(req) { !req.xhr? && req.format.html? }
end
