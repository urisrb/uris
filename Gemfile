source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# GraphQL — the browser's API. The MCP endpoint gets typed tools instead, over
# the same domain layer; neither surface wraps the other.
gem "graphql"

# The endpoint the product is actually for. Claude adds it as a custom connector
# and drives the four movements as typed tools.
gem "mcp"

# The bearer tokens the endpoint accepts. Claims are checked here; masks issues.
gem "jwt"

# Both halves of the auth client. masks-client verifies the tokens this app
# accepts; masks-rails spends the ones it holds, and keeps them in the session
# rather than in the browser.
gem "masks-client", path: "../masks/client"
gem "masks-rails", path: "../masks/engine"

# Vite builds the React SPA [https://vite-ruby.netlify.app/]
gem "vite_rails"

# Search across every resource — the query path, and the one tenancy boundary
# Postgres RLS cannot enforce.
gem "opensearch-ruby"

# Object storage. The tenant's default storage resource is an S3 bucket, so
# "upload" means write there and reference it — no special case.
gem "aws-sdk-s3", require: false

# Every operation over an unbounded number of things — sync, export, reindex,
# rule backfills — checkpoints through this.
gem "job-iteration"

# Out of stdlib as of Ruby 3.4
gem "csv"

# What the analyzers open. A spreadsheet is rows, a pkpass is a zip with a
# manifest, and an .eml is headers plus parts — none of which shell out.
gem "roo"
gem "rubyzip", require: "zip"
gem "mail"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # Hosts, endpoints, and credentials come from .env in development — the repo
  # itself names none of them.
  gem "dotenv-rails"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Explore the schema the SPA is generated from
  gem "graphiql-rails"
end

# Inspect the queues that every sync, analysis, and backfill runs through
gem "mission_control-jobs"

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
