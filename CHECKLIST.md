# Checklist

Every feature this repo is meant to have, checked against what is actually in the tree.

**103 items — 57 done · 6 partial · 34 to build · 6 deferred**, read at `c13c78a`.

|         |              |                                                        |
| ------- | ------------ | ------------------------------------------------------ |
| `- [x]` | **done**     | shipped, committed, and exercised by something         |
| `◐`     | **partial**  | exists but incomplete, or true only in one environment |
| `- [ ]` | **to build** | nothing yet                                            |
| `⊘`     | **deferred** | set aside on purpose, not a gap                        |

**A checked box is a claim, and claims rot.** Three items on this page were once checked and were
false: Solid Queue was in the Gemfile and mounted but never installed, so every job ran in-process;
the Docker image had not built since the SPA landed; `thingChanged` was wired at every layer with
nothing to fire it. All three were _configured_ rather than _exercised_. The tell is a claim with no
verb — _mounted_, _present_, _defined_ — against _runs_, _builds_, _answers_. Prefer the latter, and
where you see the former, assume it is broken until something executes it.

---

## The model

A **reference** is the unit: one object, at one place, on one resource. A **thing** groups
references — it is an identity, not a location. A document that is a PDF on S3 and a link in Drive
is one thing with two references.

- [x] **`things` → `thing_references` → `resources`** — `things` holds only identity (kind, title).
      The unique key `(tenant_id, resource_id, locator_key)` lives on the reference, where it
      describes what it always described.
- [x] **Merge is a move** — moving a reference to another thing is the primitive; merge moves them
      all; split moves one to a fresh thing; a thing left with no references stops existing. No
      tombstones and no redirects: the row is gone. `Thing#merge!`, `ThingReference#move_to!`
- [x] **Extraction belongs to the reference, not the group** — it is a fact about bytes at a place.
      Two references may legitimately disagree, and a destructive merge would otherwise lose work
      every time. A thing's searchable body is the union across its references.
- [x] **A thing can hold a raw file and a generated document side by side** — the raw PDF on `s3`
      and an `AGENTS.md` about it in `database`, as two references to one thing.
- [ ] **Finding duplicates** — the model supports merging; nothing proposes merges yet. Intended as
      background iterators over time, blocking on a cheap key before comparing, because comparing
      every thing to every other is quadratic.
- [ ] **Two-valued deletion** — forget the reference vs. delete the underlying object. Now
      three-valued: forget a thing, forget one reference, delete the bytes behind one reference.
      Conflating any of them loses data, so none of it is built.

## Tenancy

Four independent layers, each asserted separately, because a single-tenant assumption never
announces itself.

- [x] **`tenant_id` from migration #1**
- [x] **Application — `TenantScoped` default scope**
- [x] **Database — Postgres RLS, `FORCE`, non-superuser app role** — an owner bypasses RLS unless
      forced and a superuser bypasses it regardless, which is why compose creates a separate role.
- [x] **Search — a per-tenant filtered alias** — the filter is on the alias, so the engine applies
      it and no caller can omit it. RLS cannot reach the index.
- [x] **Cable — `subscription_scope` on the base subscription** — set once rather than
      per-subscription, or graphql-ruby derives the topic from the field alone and two tenants share
      a stream.
- [x] **API — tenant-checked `object_from_id`**
- [x] **Nested `Tenant.switch` restores the outer tenant**
- [x] **RLS is lifted deliberately for data migrations** — a migration runs as the table owner with
      no tenant set, so `FORCE` makes every row invisible and a backfill quietly moves nothing and
      reports success. This cost every locator in the development database once.
      `TenantIsolation#without_row_level_security`
- [x] **Indexing callbacks re-enter the tenant** — `Tenant.switch` restores the previous tenant
      before its transaction commits, so an `after_commit` that reads associations sees nothing.
- [x] **Credentials encrypted at rest**
- [ ] ◐ **Per-tenant envelope encryption and rotation** — one app-wide key set today.

## sync — resource → catalog

- [x] **Resumable through a job-iteration cursor**
- [x] **`each_iteration` enqueues, never analyzes** — iterations must finish in ~30s for graceful
      shutdown; the iterator is fan-out.
- [x] **The enumerator is a type concern** — `each_page` owns S3 continuation tokens; other types
      bring their own cursor.
- [x] **Discovery is idempotent** — `ThingReference.discover!` keys on `(resource, locator_key)`.
- [ ] **Scheduled sync** — interval, `next_sync_at`, `sync_started_at` as a lock. Today it runs only
      when asked.
- [ ] **Backfill vs forward-only**, partitioned on a watermark captured when the rule is enabled.
- [ ] **Dry-run count before enabling** — and not via `count(*)`.

## analyze — content → understanding

- [x] **The step machine** — cached results, errored steps re-run, `after:` invalidates. One short
      transaction per step rather than one held across an OCR run.
- [x] **Analysis is a workflow** — `AnalyzeThingsJob` iterates a selector and fans out, so an
      analyzer is handed a thing and sees every reference. One thing is the same job with a selector
      of one.
- [x] **First-match-wins dispatch on kind, with a fallback that claims everything**
- [x] **pdf, image, data, text, fallback** — the deterministic half, needing no model.
- [ ] **email, xlsx, doc, calendar, pkpass** — five of the nine analyzers not yet ported.
- [ ] **Dispatch on owner type, not just kind** — an email analyzer needs to claim mail before a
      blob exists, which `Kind.for_filename` cannot express.
- [ ] **Children and dependency ordering** — email blocking on its attachments.
- [ ] **Model-backed analysis** — summary, vision, classification. The expensive half. Sits on top
      of extraction rather than replacing it.
- [ ] **Model routing** onto an `openai-compatible` resource.
- [ ] ◐ **GPU fairness** — analysis has its own pool and each tenant is capped inside it, but
      nothing model-backed runs yet, so the caps have never met work that actually contends.

## search — catalog → you

- [x] **OpenSearch with a path-aware analyzer** — paths tokenize on slashes, dashes, underscores and
      dots, so a filename fragment matches.
- [x] **Indexed on commit, removed on destroy, reindexed when a reference changes**
- [x] **Analysis text folded into the body**, unioned across a thing's references.
- [ ] ◐ **One selector grammar** — `Thing.matching` is now shared by analysis and export. It covers
      id, kind, resource and query; folder, label and date are named in the plan and absent.
- [ ] **Cursor pagination built for millions per tenant** — both paths are limit-only.
- [ ] **Reindex as a resumable bulk operation**

## export — catalog → resource

- [x] **A resumable job-iteration run**
- [x] **Selector-driven** — every argument left off widens it.
- [x] **The destination must hold the storage capability**, and a thing never exports into a
      resource it is already referenced on. Enforced in the job rather than only in the tool, so the
      invariant does not depend on which caller reached it, and both halves are exercised — each was
      confirmed to fail when its guard is removed.
- [ ] **Export records the reference it creates** — export still moves bytes and catalogues nothing,
      so a backup leaves the catalog not knowing about the copy. The model can express it now.
- [ ] **Export format** — a directory tree keyed by resource and locator today; zip and
      manifest-plus-blobs are still open.
- [ ] **"Upload" as write-to-default-storage-then-reference**

## Resources

- [x] **STI, `(tenant_id, type, key)` identity, dashed type names**
- [x] **A type owns its adapter, command schema, locator shape and enumerator**
- [x] **Command dispatch validated against the schema** — unknown command, unknown argument, missing
      required argument, all refused before an adapter is reached.
- [x] **Adapters translate their own vendor errors** — nothing above `Resource` names an SDK, which
      is what lets one retry policy cover every type.
- [x] **`s3`** — AWS, R2, B2, Wasabi, MinIO and Garage on one adapter. Attach `api` and `network`.
- [x] **`database`** — the tenant's own database as storage, so a reference can point at content
      this app produced. The only type whose storage sits behind the same RLS as the catalog, so it
      carries the tenant into its own queries.
- [ ] **`imap`** — carries the `UIDVALIDITY` trap: a UID means nothing outside its generation, so it
      belongs in the locator.
- [ ] **`oauth-google`, `oauth-github`, `openai-compatible`, `docker`, `ssh-exec`, `jellyfin`,
      `openhands`**
- [ ] **Attach class `ssh`** — a CA minting short-lived certs per operation, scoped to one host and
      one forced command. Never a stored key.
- [ ] **Attach class `node`** — for CGNAT, roaming laptops, and other people's hardware.
- [ ] **Enrollment returning a short-lived signed URL** — the browser captures the secret. Until it
      exists, resources come from `db/seeds.rb`.
- [ ] ◐ **`check!`** — implemented on both types and called by nothing but a test. A resource has no
      way to be asked whether it still works, which is the first thing enrollment needs.
- [ ] **A default storage resource per tenant** — `database` is seeded for both, but nothing marks
      one as the default.

## The endpoint

`POST /mcp` — stateless Streamable HTTP, one bearer token per call.

- [x] **Eight tools** — `search_things`, `get_thing`, `analyze_thing`, `list_resources`,
      `describe_resource`, `command_resource`, `sync_resource`, `export_things`.
- [x] **The grant is the tool list** — the server is built per request from the token's scopes, so
      an ungranted tool is not registered at all: absent from `tools/list`, and `Tool not found` if
      called anyway. Not an allowlist a prompt can argue with.
- [x] **Bearer validation** — issuer, audience, subject, expiry, and the tenant claim.
- [x] **`jwks_uri` is discovered, not assumed** — the document's own `issuer` is checked against the
      expected one, so a redirected discovery document cannot point verification elsewhere.
- [x] **`aud` bound to this tenant's own `/mcp` URL** — a token minted for one tenant fails against
      another before any tenant scoping runs. The only isolation layer that works before a query.
- [x] **Protected resource metadata at both paths, and a `401` challenge carrying it** — the whole
      handshake for a client handed nothing but a URL.
- [x] **Verified against a real auth server** — registration, sign-in, consent, PKCE, a `resource`
      indicator, then the token presented here.
- [x] **A development issuer so the endpoint runs without one** — refused outside development and
      test, because a signing secret in production would make this app the issuer of its own
      credentials.
- [x] **Secrets never travel through a tool call** — no tool accepts a credential.
- [x] **GraphQL is not exposed as a tool** — a single passthrough tool cannot be partially granted.
- [ ] **SSE and resumability** — `GET /mcp` is 405. Nothing streams yet, because nothing reports
      progress yet.
- [ ] **Session semantics** — no `Mcp-Session-Id`; every request stands alone.
- [ ] **An audit log** — every call is a grant being exercised and none of it is recorded.
- [ ] **Rate limiting per token**
- [ ] **Workflow tools** — list, create, update, run.
- [ ] ⊘ **`add_thing` / `update_thing` / `remove_thing`** — adding by hand is `command_resource put`
      then `sync_resource`. Removal waits on the deletion question.
- [ ] ⊘ **Per-tenant typed tools via `listChanged`** — `command_resource` plus `describe_resource`
      instead.

## Jobs

- [x] **Solid Queue, in its own database, in development as well as production** — a backend
      configured only in production is one whose failures are only discovered there.
- [x] **The schema is a migration**, so it dumps to `queue_structure.sql` beside the primary rather
      than leaving one database described in Ruby and one in SQL.
- [x] **Two worker pools** — iterators enqueue and return; analysis computes and will serialize on
      one GPU. Sharing a pool means a large sync occupies the workers analysis needs.
- [x] **Per-tenant concurrency on analysis**
- [x] **A failure policy** — `Analyzer::Failed` is discarded, because retrying a malformed PDF
      produces a malformed PDF; `Resource::Failed` is retried, because the bytes are probably still
      there. The failure lands on the reference either way, so it is data you can search and re-run.
- [x] **Mission Control, behind HTTP basic auth**
- [ ] ◐ **Per-tenant fairness on the iterators** — analysis is capped; a tenant that starts fifty
      syncs still holds the bulk pool. Long-running work needs admission control, not a concurrency
      key, because a duration shorter than the job over-admits.
- [ ] **Runs as records** — tools that start work answer `queued` and nothing observes them after
      that. No status, deadline, cancel, or budget.
- [ ] **`solid_cache` and `solid_cable`** — both in the Gemfile, neither installed. `cable.yml`
      still points production at a redis nothing provides.

## The web app

Deliberately small: only what a chat transcript must not do.

- [x] **React SPA with urql, codegen and cable subscriptions** — the Ruby schema is the source of
      truth and the TypeScript is generated from it, so the SPA cannot drift without the types going
      red.
- [x] **GraphQL — things, references, search, resources, tenant, node**
- [ ] ◐ **`thingChanged`** — field, scope, channel and a `useSubscription` all exist, and **nothing
      calls `trigger`**, so it has never delivered an event. Not a one-line fix: a thing commits
      once per object during a sync, so the naive callback is a firehose. Wants a decision about
      what is worth broadcasting.
- [ ] **Any mutation at all** — `MutationType` still holds only the generator's `test_field`.
- [ ] **Session auth for the browser** — the SPA has no login and `/graphql` trusts a session
      nothing sets.
- [ ] **Resource enrollment** — the main reason the web app exists.
- [ ] **Visual browsing** — images and PDFs are better looked at than described.

## Packaging

- [x] **The image builds** — Node reaches the build stage only, the final image carries the compiled
      SPA and not the toolchain, and `node_modules` is pruned. Verified by building it, checking the
      manifest, and booting it far enough to enumerate every tool.
- [x] **`bin/check-boundary`** — no host, domain or secret in this repo.
- [x] **CI: brakeman, bundler-audit, rubocop, biome, typecheck, boundary**
- [x] **CI runs the whole suite** — against real OpenSearch and MinIO, with the analyzers' binaries
      installed, and **as a non-superuser**, because a superuser bypasses RLS unconditionally and
      would make every isolation test pass without proving anything. It had never run before the
      first push; it caught three real breakages immediately.
- [x] **CI builds the image** — the gap that let the build stay broken for four commits. It also
      catches what a laptop cannot: `schema.graphql` and the generated TypeScript are gitignored
      build products that exist in every working copy and no clean checkout, so both the image and
      the typecheck now generate the API layer before they need it.
- [ ] **`deploy/site.yaml`** — this repo ships the bundle its own install needs, because a
      self-hoster needs it too.
- [ ] **Deployed anywhere at all** — the image has never run outside this laptop.

## Deliberately deferred

- [ ] ⊘ **Broader test coverage** — 78 tests cover tenancy, the model and merges, both bulk jobs,
      analysis, search, resources, grants, the failure policy and the endpoint. Note the difference
      between this being deferred and CI being unable to run what exists, which is not deferred.
- [ ] ⊘ **Table partitioning** — one table, indexed, cursor pagination, OpenSearch as the query path.
- [ ] ⊘ **Resource types as extensible data** — a closed registry in code for v1.
- [ ] ⊘ **A Go node binary** — everything reachable takes `ssh`; `node` is for the rest, and later.
