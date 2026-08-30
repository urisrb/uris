# things

A data unifier — one searchable index across everything you own, wherever it lives, with a way back
out.

Drive search only searches Drive. Gmail search only searches Gmail. things searches across all of
them, with analysis attached, and can hand the bytes back as an export or a local copy.

```
sync       resource → catalog        pull references in          ✓ s3
analyze    content  → understanding  per thing, by kind          — next
search     catalog  → you            one index across everything ✓
export     catalog  → resource       bytes back out              ✓
```

A **thing** is a reference, not the bytes. The catalog is the product; originals stay in the resource
they came from. A **resource** is an instance — "my B2 bucket" — and its **type** (`s3`, `imap`,
`oauth-google`) is what decides how much code exists: one `s3` adapter serves AWS, R2, B2, Wasabi,
MinIO and Garage. A type owns its adapter, its command schema, its locator shape, and its enumerator.

Everything that touches an unbounded number of things checkpoints through
[job-iteration](https://github.com/Shopify/job-iteration), so a sync or an export survives a deploy
and resumes at its cursor rather than starting over.

## Running it

Rails runs on the host; Postgres, OpenSearch, MinIO, and Mailpit run in Docker. The analyzers shell
out to native binaries and inference runs on the GPU, so containerising the app would buy nothing
and cost the debugger.

```sh
brew bundle          # native dependencies the analyzers need
bin/setup            # services, database, two tenants, generated API types
bin/dev              # web, worker, vite, and the codegen watchers
```

Tenants are addressed by subdomain, so add these to `/etc/hosts`:

```
127.0.0.1 things.test jons.things.test acme.things.test
```

Then <http://jons.things.test:4242> and <http://acme.things.test:4242>.

## Two tenants, always

Single-tenant assumptions do not announce themselves — they leak silently through a scope someone
forgot, months later. So there are two tenants from the first seed, and every scenario in the suite
should be exercised against both.

Isolation has three layers, and the tests assert each one separately:

| Layer | Enforced by | Fails how |
|---|---|---|
| application | `TenantScoped` default scope | a forgotten scope |
| database | Postgres RLS, `FORCE` + policy | silently, if the app role is a superuser |
| search | a per-tenant filtered alias | invisibly — RLS cannot reach the index |
| cable | `subscription_scope :tenant_id` | two tenants sharing one stream name |
| API | tenant-checked `object_from_id` | `node(id:)` walks out of the tenant |

Two of those have a trap worth knowing about. A table's **owner bypasses RLS** unless the table is
marked `FORCE ROW LEVEL SECURITY`, and a **superuser bypasses it regardless** — which is why
`compose.yml` creates a separate non-superuser role for the app rather than letting Rails connect as
`POSTGRES_USER`. Both were caught by `test/models/tenant_isolation_test.rb` failing, which is what
that file is for.

## Two interfaces, one domain layer

```
browser  → /graphql   session auth, first-party client, urql + codegen + cable subscriptions
Claude   → /mcp       typed tools, token-scoped grants
```

Neither wraps the other. Exposing GraphQL *as* an MCP tool is what would collapse them back into
one — a single passthrough tool cannot be partially granted.

The Ruby schema is the source of truth and the TypeScript is generated from it, so the SPA cannot
drift from the API without the types going red first. `bin/dev` keeps both watchers running.

## The boundary rule

**Nothing in this repo may name a host, a domain, or a secret.** Those are facts about a deployment,
and they belong in the private infrastructure repo that consumes this one. Everything arrives
through the environment; `.env.example` documents what.

Run `bin/check-boundary` before committing. It is wired into CI so that the rule is greppable rather
than remembered.
