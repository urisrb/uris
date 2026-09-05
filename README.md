# thingies

A data unifier — one searchable index across everything you own, wherever it lives, with a way back
out.

Drive search only searches Drive. Gmail search only searches Gmail. thingies searches across all of
them, with analysis attached, and can hand the bytes back as an export or a local copy.

```
sync       resource → catalog        pull references in          ✓ s3
analyze    content  → understanding  per thing, by kind          ✓ no model yet
search     catalog  → you            one index across everything ✓
export     catalog  → resource       bytes back out              ✓
```

All four are reachable over `/mcp`, which is what the product is for.

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
127.0.0.1 things.test demo.things.test acme.things.test
```

Then <http://demo.things.test:4242> and <http://acme.things.test:4242>.

## Two tenants, always

Single-tenant assumptions do not announce themselves — they leak silently through a scope someone
forgot, months later. So there are two tenants from the first seed, and every scenario in the suite
should be exercised against both.

Isolation has three layers, and the tests assert each one separately:

| Layer       | Enforced by                     | Fails how                                |
| ----------- | ------------------------------- | ---------------------------------------- |
| application | `TenantScoped` default scope    | a forgotten scope                        |
| database    | Postgres RLS, `FORCE` + policy  | silently, if the app role is a superuser |
| search      | a per-tenant filtered alias     | invisibly — RLS cannot reach the index   |
| cable       | `subscription_scope :tenant_id` | two tenants sharing one stream name      |
| API         | tenant-checked `object_from_id` | `node(id:)` walks out of the tenant      |

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

Neither wraps the other. Exposing GraphQL _as_ an MCP tool is what would collapse them back into
one — a single passthrough tool cannot be partially granted.

The Ruby schema is the source of truth and the TypeScript is generated from it, so the SPA cannot
drift from the API without the types going red first. `bin/dev` keeps both watchers running.

## The endpoint

`POST /mcp` — stateless Streamable HTTP, eight tools, one bearer token per call.

|                     |                     |
| ------------------- | ------------------- |
| `search_things`     | `things:read`       |
| `get_thing`         | `things:read`       |
| `analyze_thing`     | `things:write`      |
| `list_resources`    | `resources:read`    |
| `describe_resource` | `resources:read`    |
| `command_resource`  | `resources:command` |
| `sync_resource`     | `resources:command` |
| `export_things`     | `resources:command` |

**The token decides which tools exist.** The server is built per request from the caller's grant, so
a tool outside it is absent from `tools/list` and answers `Tool not found` if called anyway — there
is no allowlist consulted at call time for a prompt to argue with. A token minted for one tenant is
rejected against another on its audience, before any tenant scoping runs.

Credentials never travel through a tool call: they would land in the transcript. Connecting a
resource is a browser flow, and that is most of what the web UI is for.

### Driving it

An unauthenticated call answers `401` with a `WWW-Authenticate` header naming the issuer to go
authenticate against — the whole handshake, for a client handed nothing but a URL.

There is no local minting path any more. A bearer token comes from masks or it does not exist: this
app verifies, and never signs. Point `MASKS_ISSUER_TEMPLATE` at a running issuer, sign in through
the web app, and the browser's session is a real token; for a raw `curl`, take one from that issuer's
token endpoint.

```sh
curl -sS http://demo.things.test:4242/.well-known/oauth-protected-resource

curl -sS -X POST http://demo.things.test:4242/mcp \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Jobs, and what happens when one fails

Solid Queue, in a second database, in development as well as production — a queue that only exists
in one environment is a queue whose failures are only discovered there. `bin/jobs` runs it and
`bin/dev` keeps it up; `/jobs` is Mission Control.

Two worker pools, because the work is two different shapes:

| Pool     | Queues                      | Why                                                 |
| -------- | --------------------------- | --------------------------------------------------- |
| bulk     | `sync`, `export`, `default` | iterators that enqueue rather than compute          |
| analysis | `analysis`                  | expensive, and serial on one GPU once models arrive |

Splitting them is what stops a hundred-thousand-object sync from occupying the workers analysis
needs. Within analysis, `limits_concurrency` caps each tenant, so one tenant with a large catalog
cannot starve another — the fairness problem a single shared pool cannot express.

**A durable queue makes failure a persistent object, so failure needs a policy.** The two kinds are
different and the error class is what distinguishes them:

|                    |                                   |                                                                   |
| ------------------ | --------------------------------- | ----------------------------------------------------------------- |
| `Analyzer::Failed` | a file that cannot be read        | **discarded** — retrying a malformed PDF produces a malformed PDF |
| `Resource::Failed` | a resource that cannot be reached | **retried** with backoff — the bytes are probably still there     |

The analysis of a thing is recorded on that thing either way: the step machine stores the error
under `analysis.steps`, so a failure is data you can search and re-run, not a row in a dead-letter
queue. Adapters translate their own vendor errors, so nothing above `Resource` names an SDK.

## The boundary rule

**Nothing in this repo may name a host, a domain, or a secret.** Those are facts about a deployment,
and they belong in the private infrastructure repo that consumes this one. Everything arrives
through the environment; `.env.example` documents what.

Run `bin/check-boundary` before committing. It is wired into CI so that the rule is greppable rather
than remembered.
