Rails.application.routes.draw do
  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  end

  mount Masks::Rails::Engine, at: "/auth", as: :masks

  post "/graphql", to: "graphql#execute"

  get "/references/:id/content", to: "content#show", as: :reference_content
  get "/references/:id/thumbnail", to: "content#thumbnail", as: :reference_thumbnail

  post "/mcp", to: "mcp#handle"
  match "/mcp", to: "mcp#unsupported", via: [ :get, :delete ]

  get "/.well-known/oauth-protected-resource", to: "oauth_metadata#protected_resource"
  get "/.well-known/oauth-protected-resource/mcp", to: "oauth_metadata#protected_resource"

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  get "*path", to: "home#index", constraints: ->(req) { !req.xhr? && req.format.html? }
end
