# uris

A data unifier — one searchable index across everything you own, wherever it lives, with a way back
out.

Drive search only searches Drive. Gmail search only searches Gmail. uris searches across all of
them, with analysis attached, and can hand the bytes back as an export or a local copy.

```
sync       resource → catalog        pull references in          ✓ eight of eleven types
analyze    content  → understanding  per item, by kind          ✓ summaries, vision
search     catalog  → you            one index across everything ✓
export     catalog  → resource       bytes back out              ✓
```

All four are reachable over `/mcp`, which is what the product is for.

A **item** is a reference, not the bytes. The catalog is the product; originals stay in the resource
they came from — with one exception, [snapshots](#snapshots), where there is no original to leave.
A **resource** is an instance — "my B2 bucket" — and its **type** (`s3`, `imap`, `oauth-google`) is
what decides how much code exists: one `s3` adapter serves AWS, R2, B2, Wasabi, MinIO and Garage. A
type owns its adapter, its command schema, its locator shape, and its enumerator.

Everything that touches an unbounded number of items checkpoints through
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
127.0.0.1 uris.test demo.uris.test acme.uris.test
```

Then <http://demo.uris.test:4242> and <http://acme.uris.test:4242>.

## Two tenants, always

Single-tenant assumptions do not announce themselves — they leak silently through a scope someone
forgot, months later. So there are two tenants from the first seed, and every scenario in the suite
should be exercised against both.

Isolation has four layers, and the tests assert each one separately:

| Layer       | Enforced by                     | Fails how                                |
| ----------- | ------------------------------- | ---------------------------------------- |
| application | `TenantScoped` default scope    | a forgotten scope                        |
| database    | Postgres RLS, `FORCE` + policy  | silently, if the app role is a superuser |
| search      | a per-tenant filtered alias     | invisibly — RLS cannot reach the index   |
| cable       | `subscription_scope :tenant_id` | two tenants sharing one stream name      |

Two of those have a trap worth knowing about. A table's **owner bypasses RLS** unless the table is
marked `FORCE ROW LEVEL SECURITY`, and a **superuser bypasses it regardless** — which is why
`db/docker-entrypoint-initdb.d`, mounted by `compose.yml`, creates a separate non-superuser role for
the app rather than letting Rails connect as `POSTGRES_USER`. Both were caught by
`test/models/tenant_isolation_test.rb` failing, which is what that file is for.

There is no `node(id:)` field and no `object_from_id`, so nothing walks the graph by global id. Add
one and it needs its own tenant check and its own test, since it would bypass the associations a
default scope reaches through.

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

`POST /mcp` — stateless Streamable HTTP, eleven tools, one bearer token per call.

|                     |                     |
| ------------------- | ------------------- |
| `search_items`      | `uris:read`         |
| `get_item`          | `uris:read`         |
| `analyze_item`      | `uris:write`        |
| `list_resources`    | `resources:read`    |
| `describe_resource` | `resources:read`    |
| `check_resource`    | `resources:read`    |
| `list_runs`         | `resources:read`    |
| `command_resource`  | `resources:command` |
| `sync_resource`     | `resources:command` |
| `export_items`      | `resources:command` |
| `cancel_run`        | `resources:command` |

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
curl -sS http://demo.uris.test:4242/.well-known/oauth-protected-resource

curl -sS -X POST http://demo.uris.test:4242/mcp \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Snapshots

Every other type points at bytes somebody else is keeping. A `web` resource does not: it drives a
headless browser at an address and the rendering it gets back — a full-page PNG and the text the
page actually laid out — did not exist until it asked. Visiting again does not produce it a second
time, so a snapshot is written into the tenant's storage resource and the locator remembers which
one, rather than being re-fetched from the URL it came from.

One item per address. Snapshotting the same page twice is a new version of one item, not a second
entry to merge later, and the version is a digest of the capture — so a page that has not changed
costs nothing and a page that has re-opens analysis on its own.

**A browser pointed at an address a caller named is an SSRF engine, and the guard the other types
use does not reach it.** `PublicFetch` checks one URL, once, at the moment it resolves. A browser
resolves again, follows its own redirects, pulls a hundred subresources and runs whatever script
the page carries, none of which passes through that check. So the rules moved down a layer into
`PublicAddress` and sit on every request the renderer makes, through CDP interception: reserved
ranges refused on each one, `file://` and `chrome://` refused whatever the address rules say, and
loopback wearing an IPv6 costume unmapped before it is judged.

The rest is containment rather than filtering. Ferrum turns off the same-origin policy and site
isolation by default, which suits a suite driving its own app and not a renderer aimed at the open
web, so both come back on. Each capture gets a browser of its own and a profile that is deleted
after, because two tenants sharing a cookie jar is not a bug you would find by reading the code.
A capture is capped in wall-clock time, in pixels — infinite scroll is otherwise a memory bomb —
and in bytes.

Chrome's own sandbox stays on. In a container that needs namespaces it may not have: give it
`--cap-add=SYS_ADMIN` or a seccomp profile that allows `clone`, and reach for
`URIS_CHROME_NO_SANDBOX` only knowing it is the last thing between a hostile page and the worker.

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

The analysis of an item is recorded on that item either way: the step machine stores the error
under `analysis.steps`, so a failure is data you can search and re-run, not a row in a dead-letter
queue. Adapters translate their own vendor errors, so nothing above `Resource` names an SDK.

## The boundary rule

**Nothing in this repo may name a host, a domain, or a secret.** Those are facts about a deployment,
and they belong in the private infrastructure repo that consumes this one. Everything arrives
through the environment; `.env.example` documents what.
