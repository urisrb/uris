
CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: JavaScript", "npm run lint"
  step "Style: everything else", "bin/fmt && git diff --exit-code"

  step "Types: TypeScript", "npm run typecheck"
  step "Tests: JavaScript", "npm test"
  step "Boot: eager load", "env RAILS_ENV=test bin/rails zeitwerk:check"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end
