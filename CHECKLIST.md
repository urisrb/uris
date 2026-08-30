# Checklist

Every feature this repo is meant to have, checked against what is actually in the tree.

**119 items — 73 done · 5 partial · 35 to build · 6 deferred**, read at `d16fc4b` plus the working
tree.

|         |              |                                                        |
| ------- | ------------ | ------------------------------------------------------ |
| `- [x]` | **done**     | shipped, committed, and exercised by something         |
| `◐`     | **partial**  | exists but incomplete, or true only in one environment |
| `- [ ]` | **to build** | nothing yet                                            |
| `⊘`     | **deferred** | set aside on purpose, not a gap                        |

**A checked box is a claim, and claims rot.** Three items on this page were once checked and were
false: Solid Queue was in the Gemfile and mounted but never installed, so every job ran in-process;
the Docker image had not built since the SPA landed; `thingAnalyzed` was wired at every layer with
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
- [x] **Scheduled sync** — `sync_interval` on the resource, `next_sync_at` as the due time,
      `sync_started_at` as the lock. A recurring `ScheduleSyncsJob` walks every tenant once a minute
      and claims each due resource with a conditional `UPDATE`, so two schedulers cannot start the
      same sync twice. The lock is released `on_complete`, which an interruption does not reach — a
      resumed sync is still holding its own lock — and a worker killed mid-sync leaves it held until
      `SYNC_ABANDONED_AFTER`, six hours, because nothing reports progress to time it any tighter.
      Exercised by running the Solid Queue supervisor: four consecutive minutes, one sync each, the
      lock taken and released every time. The first run of it was wrong — `next_sync_at` advanced
      from the _finish_, so each cycle drifted past the next tick and a one-minute interval ran every
      two. It advances on the interval's grid now, and catches up rather than replaying every run it
      missed.
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
- [x] **email, xlsx, calendar, pkpass** — the deterministic half of each, since model-backed
      summary is its own item and porting the prompts would have checked a box nothing can run. An
      `.eml` gives up headers, body and the names of its attachments — named, never extracted, since
      an attachment is a thing of its own and writing bytes from inside an analyzer is the sync
      path's job. A workbook gives up each sheet's headers and a sample of rows. RFC 5545 folding
      is the trap in `.ics`: unfold before splitting on a colon, or every long `SUMMARY` is silently
      cut. Exercised against real files through the real dispatch.
- [ ] ◐ **doc** — written, and nothing has run it: LibreOffice on this machine is killed on sight by
      the OS, and it is deliberately not in the runtime image either, being half a gigabyte. A
      `.docx` is no longer read as raw text by the text analyzer, which it was, so the failure is
      now visible rather than indexed as mojibake.
- [x] **Dispatch on owner type, not just kind** — the resource declares what its objects are.
      `Resource#kind_for` and `#title_for` default to `Kind.for_filename` on the locator key, which
      is what every file-shaped type wants and leaves s3 and `database` untouched; `imap` overrides
      both, so a message is an `email` titled by its subject and no filename is invented for it.
      The guess moved out of `SyncResourceJob`, which had no business making it.
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
- [x] **Cursor pagination built for millions per tenant** — `Page` is keyset on the primary key,
      newest first: no offset, and no count. The cursor is the last id of the previous page and one
      extra row answers "is there more", so nothing ever asks the database to count a million
      things. `things` and `runs` both take it. Search stays limit-only, because OpenSearch orders
      by score and its cursor is `search_after`, which is a different thing.
- [ ] **Reindex as a resumable bulk operation**

## export — catalog → resource

- [x] **A resumable job-iteration run** — the enumerator plucks ids up front, so a thing can be
      merged away before the cursor reaches it. The iteration skips what is no longer there rather
      than failing the whole run; cataloguing the copies made that happen on the first try.
- [x] **Selector-driven** — every argument left off widens it.
- [x] **The destination must hold the storage capability**, and a thing never exports into a
      resource it is already referenced on. Enforced in the job rather than only in the tool, so the
      invariant does not depend on which caller reached it, and both halves are exercised — each was
      confirmed to fail when its guard is removed.
- [x] **Export records the reference it creates** — the copy is a second reference to the same thing,
      keyed on the destination's own locator, so syncing that destination afterwards discovers
      nothing: the catalog does not fork a thing into a thing and a copy of it. Two consequences
      worth naming. Export is now write-once — the guard that skipped a thing already referenced on
      the destination now skips one exported last night, which is what makes a nightly backup cheap.
      And a copy landing where a different thing already lives takes that reference over, because
      after the write the bytes there are this thing's. Exercised against MinIO, the
      sync-afterwards case included.
- [ ] **Re-exporting a source that changed** — write-once has no way to know the bytes moved.
      Nothing marks a reference stale when a sync sees a new etag, so a backup of an edited file
      stays the old one. It needs a dirty signal, not a second export mode.
- [ ] **Export format** — a directory tree keyed by resource and locator today; zip and
      manifest-plus-blobs are still open.
- [ ] **"Upload" as write-to-default-storage-then-reference** — both halves now exist,
      `ThingReference.record!` and the default storage resource. What is missing is a caller, and
      that waits on the first mutation and on session auth. Building the primitive before then would
      be one more checked box whose only user is its test.

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
- [x] **`imap`** — the first type that is not object storage, and the one that proved the
      abstraction generalizes: no blob until you fetch one, a generation-scoped cursor, and read-only
      throughout. One mailbox per resource, the way one bucket is one `s3`. The `UIDVALIDITY` trap is
      handled in both directions, and both were confirmed to fail when the check is removed. A UID
      means nothing outside its generation, so the locator carries `(mailbox, uidvalidity, uid)` and
      the locator key is all three: a renumbered mailbox catalogues afresh rather than silently
      pointing at whatever now holds UID 4. A reference from a dead generation refuses to resolve
      instead of returning the wrong message. And the sync cursor is `uidvalidity:uid`, so a cursor
      from a previous generation restarts at 1 — without that check a resumed sync quietly catalogues
      nothing and reports success, which is the same failure mode as the RLS-during-migration one.
      Reads use `EXAMINE` and `BODY.PEEK[]`, so cataloguing your mail never marks it read; that is
      also asserted, and fails without the `PEEK`. The `.eml` analyzer was already there and needed
      no change, because `download` hands it the same RFC822 bytes a file would have.
- [ ] **`imap` beyond one mailbox** — no `LIST`, no folder discovery, no `CONDSTORE`, and a
      renumbered mailbox duplicates rather than rebinding, because recognising the duplicates is the
      unbuilt dedup item and guessing here would lose mail.
- [ ] **`oauth-google`, `oauth-github`, `openai-compatible`, `docker`, `ssh-exec`, `jellyfin`,
      `openhands`**
- [ ] **Attach class `ssh`** — a CA minting short-lived certs per operation, scoped to one host and
      one forced command. Never a stored key.
- [ ] **Attach class `node`** — for CGNAT, roaming laptops, and other people's hardware.
- [ ] **Enrollment returning a short-lived signed URL** — the browser captures the secret. Until it
      exists, resources come from `db/seeds.rb`. Three unbuilt things, not one: the signed URL, a
      mutation to submit a credential to, and session auth to keep that form from being open to
      anyone. And it cannot be routed around with a tool, because secrets never travelling through
      a tool call is the constraint the signed URL exists to satisfy.
- [x] **`check!`, and something that calls it** — `check!` raises, `check` runs it and records
      `checked_at` and `check_error` on the resource, and `check_resource` is the tool that asks. It
      rescues broadly, `NotImplementedError` included since that is not a `StandardError`, because a
      health check that can itself explode is not a health check; the class goes into the message, so
      a bug is stored rather than swallowed. A resource enrolled without its credentials records
      `KeyError: key not found: "access_key_id"`, which is the enrollment error message written for
      free.
- [x] **A default storage resource per tenant** — a boolean with a partial unique index on
      `(tenant_id) WHERE default_storage`, so the constraint is in the database and not only in
      `make_default_storage!`; a test bypasses the model to prove it. Only a storage-capable
      resource can hold it. `export_things` is the caller: with no destination it writes the whole
      catalog into this resource.

## The endpoint

`POST /mcp` — stateless Streamable HTTP, one bearer token per call.

- [x] **Eleven tools** — `search_things`, `get_thing`, `analyze_thing`, `list_resources`,
      `describe_resource`, `check_resource`, `command_resource`, `sync_resource`, `export_things`,
      `list_runs`, `cancel_run`.
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
- [x] **All four movements driven as one loop through the endpoint** — `command_resource put`, then
      `sync_resource`, then `search_things` returning it with `analyzed_at` set, then
      `export_things` writing it back out. Analysis having run is the part worth noting: it means
      the queue picked the job up, so resumability is executing rather than configured. The export
      skipped the one thing already referenced on the destination — six of seven written — which is
      that guard refusing a round trip on live data rather than on a fixture.
- [x] **A development issuer so the endpoint runs without one** — refused outside development and
      test, because a signing secret in production would make this app the issuer of its own
      credentials.
- [x] **Secrets never travel through a tool call** — no tool accepts a credential.
- [x] **GraphQL is not exposed as a tool** — a single passthrough tool cannot be partially granted.
- [ ] **SSE and resumability** — `GET /mcp` is 405. Runs report progress now, so the reason this
      was blocked is gone; what is left is the transport.
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
- [x] **Runs as records** — kind, status, what it processed, when it started and stopped, and what
      broke it. Every tool that starts work hands back a `run_id`, and `list_runs` and `cancel_run`
      are how you see and stop it. The Run is created before the job is enqueued, which answers the
      plan's open question as _wraps, not is_: it makes `queued` a real state and makes a run
      cancellable in the window before a worker picks it up, while job-iteration keeps owning the
      cursor. Cancellation is a flag the iteration reads, because a bulk job holds no token to
      revoke; `throw(:abort)` stops the loop and still runs the complete callbacks, so a cancelled
      sync releases its resource lock rather than holding it for six hours. Progress and the halt
      check ride the same beat — once, then every fifty. Exercised through the real queue.
- [ ] **Run budgets, and a run tree** — `plans/007` puts `max_steps`, `max_spend` and `max_children`
      on the root and has children debit it, so recursion cannot multiply an allowance. None of it
      applies until a run can start another one, which needs agent workflows. A prebuilt run has a
      deadline and a cancel flag and nothing to spend.
- [x] **`solid_cache` and `solid_cable`** — installed the way the queue was, and for the same
      reason: separate databases in development too, each described by a migration, so all four
      dump to `structure.sql` files beside each other. Production would otherwise have booted with
      an in-process cache lost on every deploy and a cable adapter dialing a redis nothing here
      provides. Exercised: a value written and read back through `SolidCache::Store` with a row in
      `solid_cache_entries`, and a broadcast landing in `solid_cable_messages`.

## The web app

Deliberately small: only what a chat transcript must not do.

- [x] **React SPA with urql, codegen and cable subscriptions** — the Ruby schema is the source of
      truth and the TypeScript is generated from it, so the SPA cannot drift without the types going
      red. Codegen had no mapping for `ISO8601DateTime` or `JSON`, so every timestamp arrived as
      `unknown`; fixed in `codegen.ts` rather than cast at each use.
- [x] **A catalog worth opening** — search, kind filters, thumbnails and a cursor on the list; a
      thing page with every reference, its analysis, open, download and split; resources with
      health, sync schedules and a default-storage star; a runs table that polls while anything is
      open and can cancel it. Built on the Mantine, react-router and Tabler dependencies that were
      already in `package.json` and entirely unused.
- [x] **GraphQL — things, references, search, resources, tenant, node**
- [x] **`thingAnalyzed`** — fires when an analysis finishes, which is the answer to the question that
      kept it unwired: a thing commits once per object during a sync, so the naive `after_commit` is
      a hundred thousand events, while analysis is both the moment a thing became worth looking at
      and the only step already rate-bounded, running in its own pool behind a serial GPU. It takes
      an optional `id`, so a client can watch one thing rather than the whole tenant, and both
      topics fire. Tenancy is in the topic rather than the payload: two tenants on the same field
      land on different streams, asserted. Exercised through the real channel in test, and against
      real solid_cable in development. The hop from the event stream to one subscriber is
      graphql-ruby's own listener and needs a live client to see.
- [x] **Mutations** — nine: analyze, merge, split, sync, check, `setDefaultStorage`,
      `setSyncInterval`, export, `cancelRun`. Each goes through the same model method its tool does,
      so there is one set of rules behind two front doors rather than a second implementation that
      drifts.
- [ ] **Session auth for the browser** — the SPA has no login and `/graphql` trusts a session
      nothing sets.
- [ ] **Resource enrollment** — the main reason the web app exists.
- [x] **Visual browsing** — `/references/:id/content` streams a reference out of whatever resource
      holds it, chunked rather than read whole into memory, and `/references/:id/thumbnail` renders
      images through `vipsthumbnail` and a PDF's first page through `pdftoppm` at three sizes. A
      thumbnail is a derivative, not data — regenerable from the reference — so it lives in the
      cache and never in a table anyone has to migrate. A kind with nothing to render answers 404.
- [x] **The image carries what the analyzers shell out to** — `poppler-utils` and `tesseract-ocr`
      were missing while `libvips` was present, so `pdfinfo`, `pdftotext`, `pdftoppm` and OCR all
      worked on a laptop that has them from the Brewfile and failed everywhere else. Installed.
      LibreOffice stays out on purpose: half a gigabyte is a trade to make deliberately, and the
      `doc` analyzer is the only thing that wants it.

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

- [ ] ⊘ **Broader test coverage** — 130 tests cover tenancy, the model and merges, runs, both bulk jobs,
      the sync schedule, analysis, search, resources, grants, the failure policy and the endpoint.
      Note the difference
      between this being deferred and CI being unable to run what exists, which is not deferred.
- [ ] ⊘ **Table partitioning** — one table, indexed, cursor pagination, OpenSearch as the query path.
- [ ] ⊘ **Resource types as extensible data** — a closed registry in code for v1.
- [ ] ⊘ **A Go node binary** — everything reachable takes `ssh`; `node` is for the rest, and later.
