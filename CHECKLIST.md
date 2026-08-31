# Checklist

Every feature this repo is meant to have, checked against what is actually in the tree.

**147 items — 105 done · 7 partial · 29 to build · 6 deferred**, read at `768c938` plus the
handshake work in the tree. The suite was run rather than cited: **272 runs, 718 assertions, 0
failures**.

**The rename landed.** *Handshake* is the request and *connected* is the state, in both repos and in
all three client libraries — and the flow itself moved into `masks-rails`, so this app no longer
owns a line of it. What is left here is where the credentials are read from and written to.

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
- [ ] ◐ **API — `object_from_id` is tenant-checked and unreachable** — it compares `tenant_id`
      correctly, and nothing can call it. `Query.node` and `Query.nodes` are declared, but **no type
      implements the `Node` interface**, so graphql-ruby prunes the interface and both fields out of
      the built schema: `{ node(id: …) }` answers *"Field 'node' doesn't exist on type 'Query'"*.
      A checked box for code with no caller. Either wire `implements Types::NodeType` into the types
      that should be fetchable by global id, or drop the field and the resolver together — the one
      thing not to leave is a tenancy layer that reads as present and is not in the schema.
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
- [x] **The search index is idempotent to create** — both halves of index setup were check-then-act,
      and OpenSearch answers "does this exist" from cluster state that has not necessarily caught up
      with the delete that just happened. The suite failed differently every run — a 404 from
      `reset!`, or a 400 `resource_already_exists` from `create!` reached through `Tenant.switch` —
      and passed again after deleting `things_test` by hand, which reads as broken code rather than
      a broken fixture. Neither operation needs to ask: the delete ignores 404, the create rescues
      already-exists.
- [x] **Reindex as a resumable bulk operation** — `ReindexThingsJob` walks a tenant's catalog by
      keyset in pages of two hundred, so nothing holds a million ids in memory and an interrupted
      run carries on from the thing it was on. It is a run like any other: gated, dry-runnable,
      cancellable, and counted. `search:reindex` is the routine form — repair drift, or catch up
      what a rebuild missed.
- [x] **Every name in the index is an alias, so a mapping change is not downtime** — the concrete
      index is versioned and nothing outside `SearchIndex` knows what it is called. `search:rebuild`
      builds a new one with today's mapping, fills it, and promotes it in **one** `update_aliases`
      call, so no query ever sees a moment with no index behind it or two. The per-tenant filtered
      aliases move in that same call with their filters, which is what keeps the search-side
      isolation true across a swap — a tenant alias is never briefly absent, and never briefly
      unfiltered.
      **Promotion refuses an index holding less than it was told to expect**, because a half-built
      index that answers is worse than one that does not exist, and a rebuild that fails leaves its
      index for `search:indices` to show and `search:drop` to remove — which refuses the one being
      queried. Driven against a real cluster rather than asserted: the dev index was rebuilt,
      promoted, listed and dropped, and all six tenant aliases arrived on the new index with their
      filters.
      **Writes during a rebuild land in the old index and are not in the new one.** The catch-up is
      `search:reindex` after the swap, and the task says so when it finishes rather than pretending
      the window is not there.
      Bulk indexing is the obvious next step: this puts one document per request, which is fine for
      an operator command and would not be for a nightly one.

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
- [x] **Re-exporting a source that changed** — it is a dirty signal rather than a second export
      mode, as this item asked for. A reference records the `version` its resource reports for
      those bytes, a sync that sees a different one stamps `changed_at`, and a copy records the
      `source_version` it was made from. Export rewrites in place exactly when the two disagree —
      so a backup of an edited file is the edited file, and a copy somebody else overwrote at the
      destination is still left alone, because that is not the source moving.
      **The version is the type's business, like the locator it comes out of**: an etag for `s3`
      and the WebDAV family, `modified_at:size` for `filesystem`, the entry's `published_at` for
      `rss`, the blob's `updated_at` for `database`, and **nothing for `imap`**, where a message
      inside a `uidvalidity` cannot change. Where a type reports no version, nothing claims to know
      the bytes moved and write-once behaviour stands.
- [x] **A changed reference is analyzed again, and only that one** — the same signal, consumed by
      machinery that already existed. `analyzed_at` is cleared, which is what the sync job already
      reads to decide whether to enqueue analysis, and the step machine treats any step that
      finished before `changed_at` as superseded. So re-analysis after an edit recomputes rather
      than returning the cached reading of bytes that are gone, and a reference that did not move
      is not re-read however often it is synced. `changed_at` rides along on `get_thing`, so a
      caller can see that what it is reading predates the file.
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
- [x] **`carddav`** — the same subclass trick a second time, pointed at `.vcf`, plus the contact
      analyzer that was missing. `vcf` joins `Kind`, so a vCard found on any resource is a contact,
      not only one arriving over DAV. Two vCard traps, both asserted and both failing when the guard
      is removed: RFC 6350 folds long lines exactly as iCalendar does, and Apple exports group
      properties as `item1.EMAIL`, so a parser reading the name before the dot invents a new field
      per contact. `N` and `ADR` are one value with semicolons inside, so they split on *unescaped*
      semicolons only — and unescaping has to happen per component afterwards, or `\;` is already a
      plain `;` by the time the split sees it.
- [x] **`\,` and `\;` survive unescaping** — `unescape` read `$1` after `$1 =~ /[nN]/`, and that
      comparison is itself a match: it resets `$~`, so the following `$1` was nil and every escaped
      comma and semicolon was replaced with nothing. It was written once and copied, so `calendar`
      had shipped with it — every `.ics` summary silently lost its punctuation. The calendar
      analyzer had no test at all despite being listed as exercised, which is how it survived; it
      has one now.
- [x] **`webdav` and `caldav`** — the second storage type, which is what makes storage an
      abstraction rather than a description of S3. `caldav` is a subclass of `webdav` rather than a
      type of its own, because a calendar collection *is* a WebDAV collection full of `.ics`: it
      narrows the walk to calendar objects, drops `put`, and declares its kind, and the existing
      `.ics` analyzer reads what arrives without knowing it came from a server. That is the second
      time an analyzer needed no change to meet a new type, which is the whole argument for the
      reference being the unit.
- [x] **The SSRF guard is shared, not copied** — `rss` and `webdav` both fetch a URL a tenant chose,
      so `PublicFetch` holds one implementation: scheme, resolved address, redirects re-checked per
      hop, capped, and size-bounded. A second copy is how two behaviours drift into one name.
- [x] **The walk cursor compares path segments, not strings** — depth-first over sorted names does
      not produce lexicographic *string* order: `a/x` is walked before `a.txt` and sorts after it,
      because `.` is below `/`. So `path <= cursor` resumed in the wrong place, silently, on any
      tree holding both a directory and a file sharing a prefix. Comparing `split("/")` matches the
      traversal exactly. It was wrong in `filesystem` first and inherited into `webdav`; both are
      fixed and a test pins the ordering rather than the happy path.
- [x] **`rss`** — the first type whose references point at something the catalog does not hold. A
      feed entry is a link and a summary; the bytes live at someone else's URL, which is the
      "a link in Drive" half of the model that nothing had exercised. RSS and Atom parse to the same
      entry through `local-name()`, so neither namespace is special-cased. `Analyzer::Feed` strips
      the entry body to text so it lands in the index. Two things this type taught. A feed serves a
      window, not a history: an entry that scrolls off raises `Rss::Gone` rather than resolving to
      nothing, which is the first live example of the unbuilt staleness item — the catalog outlives
      the resource's ability to answer for it. And the URL is tenant-supplied, so fetching it is
      SSRF: the scheme must be http or https, the resolved address must not be loopback, private or
      link-local unless `THINGS_ALLOW_PRIVATE_FETCH` is set, the check runs again on every redirect
      hop rather than only the first, and redirects are capped. All three were confirmed to fail
      when removed — the redirect-hop one matters most, since redirecting to `127.0.0.1` is the
      standard way around a check that only reads the URL it was handed.
- [ ] **DNS rebinding on feed fetches** — the address is checked and then connected to by name, so
      a host that resolves differently between the two wins. Closing it means connecting to the
      address that was checked and carrying the `Host` header, which is a bigger change than the
      guard it strengthens.
- [x] **`filesystem`** — a directory tree as a resource, storage and syncable, needing no credential
      and no service to test against. The enumeration is the easy half; the whole risk of this type
      is that a tenant who names its own root reads the server. So the root must sit under one of
      `THINGS_FILESYSTEM_ROOTS`, which is unset by default, meaning the type is unusable until an
      operator decides what is mountable — the paths stay in the environment, never in this repo.
      Four guards, each confirmed to fail when removed: the root is checked against that list; a
      locator is confined by `realpath` under the root, so a symlink out is refused; the walk skips
      symlinks entirely rather than following them; and writes resolve the nearest existing ancestor
      before creating anything, because resolving a parent that does not exist yet fails every
      export into a fresh directory. A lexical check runs before any of it, which is not redundant
      the way it first looks: without it a path climbing out reports "cannot resolve" for a missing
      file and "resolves outside" for a real one, which is a file-existence oracle for the whole
      disk. Both now answer identically, and that is the assertion.
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
- [x] **Gates — every iteration is switchable while it runs** — a row keyed by `(tenant, key,
      reference)` carrying `enabled` and `live`, most specific winning: a gate on one resource beats
      the key-wide gate, and absence means the iterator's own declared default rather than "off", so
      nothing silently stops working the day the table appears. `sync`, `export` and `analyze`
      declare theirs. Read on the beat `TrackedRun` already flushes progress on — once, then every
      fifty — because a gate read per record is a query per record, which is the thing that beat
      exists to avoid. Two traps, both asserted and both failing when the fix is removed. A closed
      gate returns an *empty* enumerator rather than `nil`: job-iteration skips a nil-enumerator job
      without running its completion callbacks, so `release_sync` never fires and a gated-off sync
      strands its resource for six hours — the exact lock this design was careful about everywhere
      else. And a reference-scoped gate has to load its own resource, since the gate is read before
      the enumerator has loaded anything, and a gate that cannot see its subject reads as open.
- [x] **`live` separately from `enabled`** — enabled but not live is a dry run: it walks, counts and
      reports, and writes nothing. That is how a destructive sweep gets turned on — you watch it
      describe its work first. `gated` is its own run status, because a gate closing is neither a
      failure nor something anybody cancelled.
- [x] **An operator switch that is not a row** — `THINGS_ITERATORS_DISABLED` stops everything for
      everyone. It is environment rather than data on purpose: a global row would need
      `tenant_id NULL`, which RLS makes invisible to the app that has to read it.
- [ ] **The iterator registry, the live stream, and the page** — the gate is the half that had to be
      right. What is left is enumerating iterators as data, broadcasting run events over the cable
      `thingAnalyzed` already proved, and the admin page that turns them on and off.
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
- [x] **GraphQL — things, references, search, resources, tenant** — `node` is declared and is not in
      the built schema, so it does not belong on this line; see the `object_from_id` item above.
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
- [x] **Session auth for the browser** — the SPA had no login and `/graphql` trusted a session
      nothing set. `GraphqlController` built its context as `{tenant, tenant_id}`: no subject, no
      scopes, nothing, so every mutation above was reachable by anyone who could resolve the
      subdomain. See **Auth** below.
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

## Auth

`plans/019`. The endpoint had a real bearer check from the beginning; the web app had nothing. The
fix was not a second auth system beside `Grant` but to **stop writing auth here at all** —
`app/models/issuer.rb` and `ProtectedResource` were masks-client re-implemented, and both were
written after that gem existed.

- [x] **Adopted `masks-client`, and the local copies are deleted** — `app/models/issuer.rb` was
      `Masks::Client::Verifier` with a `Rails.cache` in front and `ProtectedResource` a hand-written
      `WWW-Authenticate` header; both are gone. The gem grew the resource-server half it was missing,
      which is what made writing them here feel necessary. The one property they had that the gem did
      not — checking that a discovery document names the issuer it was fetched from, so a redirect
      cannot point verification elsewhere — moved into the gem rather than being dropped.
- [x] **`Grant` is built from `Masks::Client::Claims`, and stays** — a grant is a `things` concept:
      `things:read`, `resources:command`, and the tool list they select. masks neither knows those
      scopes nor should. What left `Grant` is `JWT.decode`; what remains is the tenant check and the
      mapping from scopes to tools.
- [x] **`masks-rails` is mounted at `/auth`** — the BFF: tokens live in the encrypted Rails session
      and never reach JavaScript, so XSS cannot lift one and there is no refresh loop in the page.
- [x] **`/graphql` accepts a session or a bearer token, by one path** — the session's own access
      token is verified exactly as a presented one is, rather than trusted because it came from a
      cookie. So a cookie and a bearer arrive at the same `Grant` through the same code, and a
      resolver cannot tell them apart. `Granted`
- [x] **A refusal fits the caller** — a request that presented a token gets the RFC 6750 challenge;
      one that did not gets `401 {login_url}`, because a browser needs somewhere to go and a
      connector needs `resource_metadata`. `/mcp` always answers the challenge: a connector is handed
      a URL and nothing else, so sending it to a login page would strand it.
- [x] **Scope is checked at the type as well as the field** — a field grant only covers the entry
      point, and `things { nodes { references { resource { key } } } }` walks from a thing to a
      resource without passing `Query.resources` again. So a `things:read` token read every
      resource's details through nesting, which is the same shape of hole as a passthrough tool.
      `ThingType` and `RunType` now want `things:read`, `ResourceType` wants `resources:read`, and
      graphql-ruby checks each on the way down. Two tests: the walk is refused on a read scope and
      completes when both are held.
- [x] **Every field and mutation declares the scope it needs** — `grants:` on the field, checked in
      `authorized?`. Reads want `things:read`, the resource list `resources:read`, mutations
      `things:write` or `resources:command` — the same scopes the tools use, since both front doors
      already go through the same model methods. **Named `grants:` and not `scope:` because
      graphql-ruby's `Field` already defines `scope:`** for `scope_items`, and the collision silently
      disabled it: the first version of this looked right, typechecked, and enforced nothing.
- [x] **The cable connection authenticates, and did not** — `ApplicationCable::Connection` was
      `identified_by :tenant` alone, resolved from the host, so anyone who could reach a tenant's
      subdomain could open a websocket and subscribe to its analysis events. Securing `/graphql` did
      not touch it: subscriptions arrive over cable, not HTTP. The connection now reads the same
      encrypted session the BFF writes, verifies the access token in it exactly as the HTTP path
      does, and carries the resulting `Grant` into the channel's GraphQL context, where
      `thingAnalyzed`'s own `grants:` then applies. Seven tests, including a session holding another
      tenant's token and one holding nonsense.
- [x] **The SPA gates on `/auth/session`** — identity before the first query, a sign-in screen when
      there is none, who is signed in and a way out in the header, and a `401` from `/graphql`
      sending the browser to masks. UI that hides a button is not a permission check; the token
      still enforces.
- [x] **`/references/:id/content` and `/thumbnail` want `things:read`** — they stream bytes out of a
      resource, and had the same nothing `/graphql` had. A thumbnail URL in an `<img>` tag cannot
      carry a bearer header, which is the second reason the browser path is a cookie.
- [x] **`MASKS_DEV_SECRET` and the HS256 branch are deleted, not left dormant** — `plans/018` filed
      this and it survived until now. A dormant branch minting credentials is a branch someone
      enables.
- [x] **The suite verifies real RS256 against a real JWKS** — a signing issuer per test worker,
      serving discovery and JWKS over a socket, **with a separate key per tenant**, so a token minted
      for one is unintelligible to another rather than merely unauthorized. That is strictly stronger
      than the shared HS256 secret it replaces, which could not fail that way. Nine tests cover the
      refusals: no credentials, a bad token, another tenant's token, a read scope against a mutation,
      a read scope against the resource list, and content without a grant.
- [x] **The browser half is driven end to end** — `/auth` → the issuer → `/auth/callback` → a
      session → `/auth/session` → a GraphQL query on the cookie alone, against a signing issuer that
      serves discovery, JWKS and a token endpoint over a socket and checks the PKCE verifier. Twelve
      tests, including a forged `state`, a callback with nothing in flight, a code the issuer never
      issued, and a code redeemed twice. This was the largest unexercised surface in either repo,
      and running it found two real defects: the session cookie overflowed at 4247 bytes because
      three JWTs were kept in it, and a token response with no `access_token` established a session
      holding `nil`. Both are fixed in masks, where every consumer gets the fix.
- [ ] ◐ **The suite still fakes the issuer, not masks itself** — the flow is real and the server is
      not, so a change to masks' own token endpoint would not fail anything here. What used to be
      wholly untested between the two is now partly driven: `home/bin/probe-handshake` runs the
      handshake, the approval, the redemption and the sign-in after it against a live masks in a
      container, twenty-two checks.
      That covers registration and consent, and covers them where they actually happen. It is a
      script somebody runs, not a suite, which is the half still missing.
- [ ] **Signing out of masks, not just of `things`** — `masks_forget` drops the local session and
      leaves the issuer's, so signing in again is silent. Correct for a shared browser only if the
      person expects it, and RP-initiated logout is unbuilt on both sides.
- [x] **This app shakes hands for itself, and holds its own credentials** — `plans/020`, and it was
      the item above this one for as long as `MASKS_CLIENT_ID` was a blank line in `.env.example`
      that nothing could fill. A first-party app must not self-register anonymously, because that is
      how a stranger's connector also arrives; so an unconnected tenant is offered the handshake,
      one button sends the browser to its own issuer's approval screen, and the one-time token that
      comes back is redeemed at `/register` server-side. The secret never travels a browser and
      nobody types it anywhere.
      **The flow is not written here any more.** It was sixty lines of state, `iss` checks, refusal
      pages and a redeem call whose metadata had to agree with what the connect URL sent — all of
      which every consumer of masks would have rewritten. It lives in `masks-rails` now, and this
      app supplies the two ends only a consumer knows: `config.credentials` reads them off the
      tenant, `config.store` writes what came back. **The whole integration is two lambdas.**
      **The two-env-vars note is superseded, as it said it would be.** The credentials are a row —
      `client_id`, `client_secret`, `registration_access_token`, `registration_client_uri`,
      `connected_at` on `tenants`, the two secrets encrypted — because a handshake is per tenant and
      each one gets a different secret, so there is no single value an env var could hold. A test
      reads the raw column rather than trusting `encrypts`.
- [x] **The unconnected screen says only that it is unconnected** — it is public, so it does not name
      the issuer or admit whether one exists; the issuer appears only in a redirect somebody asked
      for. **This survived the move into the engine, and nearly did not**: the engine's page named
      the issuer it was about to send you to, which is friendlier and is exactly the leak this item
      exists to stop — a stranger who learns an unclaimed masks hostname can claim its tenant first.
      Once connected, the handshake is not offered again to a browser that is not signed in, so a
      stranger cannot make a running install rotate its own credentials.
- [x] **An unconnected app refuses differently from a signed-out one** — `handshake_required` with
      the URL to go to, rather than `login_required` pointing at a sign-in that cannot complete
      without a client. The SPA reads it off `session.status()` and offers *Connect it* instead of
      *Sign in*; a browser navigation is redirected there. What used to happen was a redirect to
      masks carrying `client_id=`, and masks answering a stranger an error page about a client that
      does not exist.
- [x] **A signed-in actor now holds `things:*`, because approving granted them** — masks narrows a
      token to the scopes the actor holds, and a fresh actor held only the four masks defines, so
      the first real sign-in used to **succeed** and then refuse every field with `this token does
      not carry things:read`. The grant had to be made on the masks side and now is: the approval
      screen grants the approving actor what the client declares, and the descriptions on it come
      from this app's own RFC 9728 document rather than from anything masks knows. Driven end to
      end by `home/bin/probe-handshake`, which reads the scope out of the access token at the far
      end.
- [x] **The redirect_uri is resolved from the same origin as the resource** — it was
      `request.base_url` while the resource was `THINGS_PUBLIC_ORIGIN`, so tunnelling made the two
      disagree. masks pins both at approval, which turns a latent mismatch into a refusal.
- [ ] **The session is a cookie, at 2476 bytes of 4096** — measured after the id token was dropped.
      It fits, and it is 60% spent, and a cookie session cannot be revoked while it holds a refresh
      token. `solid_cache` is already installed, so `config.session_store :cache_store` is one line
      and removes both. Not done because nothing has been deployed yet and the ceiling is not
      currently being hit.
- [ ] **The resource identifier is `…/mcp` for both surfaces** — `/graphql` accepts tokens whose
      `aud` names the MCP endpoint, because that is the URL already registered and verified. One
      resource for one app is right; the name is now wrong for half of what it covers.

## Packaging

- [x] **The image builds, and until now it could not have** — Node reaches the build stage only, the
      final image carries the compiled SPA and not the toolchain, and `node_modules` is pruned.
      **The gems and the npm package are path-referenced across a workspace that is not a repo, and
      a path outside the build context does not exist inside it**: `bundle install` answered *the
      path `/masks/client` does not exist* the moment the engine was adopted, and the running dev
      container was an image built before that. The three packages arrive as named build contexts —
      `masks-client`, `masks-engine`, `masks-web` in `home/dev/compose.yml` — landing at the same
      relative paths the Gemfile and `package.json` already name, and `/masks` is carried into the
      runtime stage because a path gem is loaded from its source at boot. Publishing is still the
      real fix; this is what makes the stack boot until then.
- [x] **`bin/check-boundary`** — no host, domain or secret in this repo.
- [x] **CI: brakeman, bundler-audit, rubocop, biome, typecheck, boundary**
- [ ] **The suite hangs about one run in ten, in parallel only** — 235 tests pass serially every
      time and in parallel most times; occasionally the run never finishes and has to be killed. Not
      reproduced under any subset: the socket-backed resource tests, the jobs and the integration
      tests each ran clean repeatedly at four workers, and three full runs caught in the act showed
      no blocked query and no lock wait in `pg_stat_activity`. So it is recorded rather than
      diagnosed. It matters more than a flaky failure would, because a hang has no output to read
      and CI will sit on it until the job times out.
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

- [ ] ⊘ **Broader test coverage** — 235 tests cover tenancy, the model and merges, runs, gates, both
      bulk jobs, the sync schedule, analysis, search, all eight resource types, grants, the failure
      policy and the endpoint. Note the difference between this being deferred and CI being unable
      to run what exists, which is not deferred.
- [ ] ⊘ **Table partitioning** — one table, indexed, cursor pagination, OpenSearch as the query path.
- [ ] ⊘ **Resource types as extensible data** — a closed registry in code for v1.
- [ ] ⊘ **A Go node binary** — everything reachable takes `ssh`; `node` is for the rest, and later.
