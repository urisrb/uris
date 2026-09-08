# One record, one pass

A feed is the root record — a file, a note, an address, a tag — and an analysis is the one
record of a pass over it. Twelve MCP tools are four.

Written 2026-09-08, replacing the feeds plan, whose whole subject was absorbed: a feed used
to mean a prompt with an address, and that is now a `uris:feed` row with a schedule beside it.
Ordered by dependency; each phase is usable on its own and the one after it assumes the one
before landed.

Background: `~/Projects/things` is the prior art for the shape — its `Space` is our `Resource`,
its `Blob` roles are our reference roles, and it replaced Active Storage rather than adapting it.

## Decisions still open

- [x] **A mime type is a feed of its own.** `uris:mime`, keyed `text/markdown`, a singleton like
      a tag and an address. A content type is a thing in the catalog — it can carry a title, a
      note and connections a tag has no business holding, and keeping it out of `uris:tag` means
      the tag facet is what a person filed rather than what a parser guessed. Decided 2026-09-08.
- [ ] **What re-analysis costs.** An analysis that writes an edge re-analyzes the feed on the
      other side, which cascades without a cooldown. Per-feed cooldown, a depth cap, or a cause
      that refuses to write edges — one of the three, and it decides how lively the catalog is.
- [x] **Type is a small closed vocabulary, not a mime.** Five values, because the SPA renders by
      type. Decided 2026-09-08 at four; `uris:mime` made it five the same day.
- [x] **Edges are symmetric and unlabelled.** Decided 2026-09-08.
- [x] **Placement is decided per file by the agent**, from what each resource declares it
      accepts, with the reason recorded. No routing table. Decided 2026-09-08.
- [x] **Active Storage stages an upload and nothing else.** Resources stay hand-rolled.
      Decided 2026-09-08.

## Phase 0 — the schema

- [x] `feeds` — `(type, key)`, partial unique on the singleton types, `inheritance_column = nil`
- [x] `feed_references` — role, mime, size, digest; the locator uniqueness carried across
- [x] `feed_edges` — canonical pair, check constraint forcing `a_id < b_id`
- [x] `analyses` — cause, status, steps, turns, logs, deadline
- [x] `schedules` — the old feed's scheduling half, keyed by feed
- [x] `items`, `item_references`, `feed_items`, `prompts` dropped; RLS on all five new tables

**Phase 0 landed 2026-09-08.** Greenfield: `db:reset` and reseed, no data migration.

## Phase 1 — the models

- [x] `Feed`, `Reference`, `Edge`, `Analysis`, `Schedule`; `Item`, `FeedItem`, `Prompt`,
      `Kind` and `Feed::Harvest` deleted
- [x] `MimeType` replaces `Kind` as the extension map, and `kind` becomes two things: a `mime`
      column on the reference, and an edge to a `uris:tag`
- [x] `Blocking`'s raw SQL rewritten — the same-name key is now `(type, lower(key))`
- [x] `Analyzer::Feed` renamed to `Analyzer::Entry`, because inside `module Analyzer` it shadowed
      the `Feed` model and every constant lookup would have resolved to the analyzer

**Phase 1 landed 2026-09-08.** Two bugs written and caught on the way: a literal NUL byte in
`analysis.rb` (which made grep treat the file as binary), and then `String#delete("\\u0000")`
written with a doubled backslash — `delete` takes a character _set_, so it stripped every `\`,
`u` and `0` from every stored string. It surfaced as `result` → `reslt`.

## Phase 2 — the pass

- [x] `AnalyzeFeedJob` replaces `AnalyzeItemJob`, `AnalyzeItemsJob` and `RunFeedJob`
- [x] `Analyzer.for` dispatches on mime; `Analyzer::Base#step` writes into `analysis.steps`
- [x] `converse` and `complete` record turns into `analysis.turns` rather than opening a `Prompt`
- [x] A feed is analyzed once, reading whichever reference can be read
- [x] The mime tag is connected mechanically; `Run` keeps `analyze` for the bulk fan-out

**Phase 2 landed 2026-09-08.**

## Phase 3 — the loop

- [x] `Agent` returns an `Answer(said:, reason:, turns:, calls:)` rather than a string or a symbol
- [x] `Agent::Transcript` strips reasoning before replay and caps a tool result at a byte budget
- [x] `Agent::Dispatch` validates through the tool's own `input_schema` — the same
      `missing_required_arguments?` then `validate_arguments` the MCP server runs — then drops
      keys the schema does not declare, and rescues `ArgumentError` as the backstop
- [x] Three malformed calls in a row end the run `:flailed`
- [x] The last turn is offered no tools and asked for an answer
- [x] `test/models/agent_test.rb` — the first coverage this code has ever had

**Phase 3 landed 2026-09-08.** 11 tests. `agentTurned` is gone rather than fixed: turns are
logged to the analysis, so `analysisProgressed` is the one live stream.

## Phase 4 — four tools

- [x] `search`, `feed`, `connect`, `resource`
- [x] `search_web` absorbed into `resource` — `Resource::Search` already declares the capability
- [x] Commands declare read or write; `Tool::Resources.for(grant)` builds the schema per grant, so
      an ungranted command is absent from `tools/list` rather than refused at call time
- [x] `uris:web:read` still gates a search-capable resource, so the granularity survives
- [x] `Feed#grant` carries four scopes rather than every scope but admin

**Phase 4 landed 2026-09-08.**

## Phase 5 — the suite loads again

54 of 80 test files name a collapsed model, so `bin/rails test` does not load at all. Nothing
below can be checked until this lands.

- [x] Port the tests whose subject did not change — tenant isolation, RLS, the resource adapters,
      sync, export, merge, search — because that coverage is expensive to regrow
- [x] Delete the tests whose subject no longer exists: the `kind` vocabulary, feed-as-prompt, and
      the per-tool tests for the eight tools that are gone
- [x] Regrow MCP coverage against `search`, `feed`, `connect` and `resource`
- [x] A tenant-isolation case per new table — RLS is per-table and does not come for free
- [x] `test/models/edge_test.rb`: the canonical-pair constraint refuses a reversed duplicate

**Phase 5 landed 2026-09-08.** 767 runs, 0 failures, 6 skips. Only one file ever failed to
_load_ — a stale constant in a frozen list — because a constant named inside a method body is
not resolved until it runs; the runner aborts on the first load error, which made one look
like fifty. The rest were failures, and porting them turned up ten defects the refactor had
left behind, each now a `fix` of its own:

- `SyncResourceJob` still asked a resource for `kind_for`, so every sync raised on its first
  object. Every adapter had already been renamed to `mime_for`.
- `QueryType` declared `feed` and `feeds` twice, which made the schema refuse to build — and
  the later `def feeds` shadowed the paged resolver, so `after:` and `limit:` were ignored.
- A pass started with no steps, so re-analysing re-ran extraction and paid for the summary
  again. An analysis opens with the steps the last settled one left.
- The index was written from the reference's `after_commit`, which fires while the analysis is
  still running, so `analyses.settled.last` was nil and every summary indexed empty.
- `Feed#analyzed_at` read the analysis, so a pass that deliberately did nothing — a message
  whose attachments are not read yet — came back analyzed, and `children_ready?` believed it.
- The run budget was declared per tool, and `resource` carries sync and export, so listing the
  places spent from the hourly ceiling.
- `run_progressed` triggered only the gid topic. It is the raw id and the wildcard now, which
  also closes the gap recorded below.
- A merge destroyed every pass ever made over the absorbed copy.
- `feed_edges` has a foreign key and nothing cascaded, so destroying any connected feed — which,
  since the mime tag is connected mechanically, is every analyzed feed — raised.
- An embedding was staled by writing to the reference. The pass settling is what stales it.

Two subjects changed rather than moved, and the cases say so. The blocking key is
`(type, key)`, so two files sharing a name are proposed whatever their bytes are. And a pass
belongs to the thing rather than to each copy of it, so a merge carries passes rather than a
per-reference extraction.

`AnalyzeFeedJob` opens its own analysis when it is handed no id. It had one caller, which
always passed one, and every `analysis&.` in the job meant a pass run any other way did its
work into nowhere.

## Phase 6 — resources declare themselves

- [x] `serves` / `accepts` / `up_to` as a class macro, mirrored to a `resources.serving` jsonb
      column on save, so "which resources accept a 4GB video?" is indexed SQL rather than
      `capable_of` loading every active resource into Ruby
- [x] `resource(do: "list")` reports what each accepts, which is what the agent reads
- [x] `config/resources.yml` — ERB, per environment, every host and secret through `ENV`
- [x] `Resource.declare!` reconciles per tenant, applying only fields that type's `attaching`
      declares — that rule is `Resource::Settings` now, asked by both the file and the form
- [x] Called from `bin/docker-entrypoint`, which already runs `db:prepare`
- [x] A shipped container comes up with a filesystem resource on a declared volume and
      `URIS_FILESYSTEM_ROOTS` set to match; `db/seeds.rb` goes back to two dev tenants
- [x] ~~Eager-load the subclass directory in development, or the macro never runs~~ — not
      needed. Nothing enumerates `Resource.subclasses`; every reader goes through `TYPES` and
      `find_sti_class`, which autoloads, and the row is what a query reads rather than the class

**Phase 6 landed 2026-09-08.** `Resource.declared!` is `declare!`, for symmetry with
`Tenant.declare!`, which it stands beside in the entrypoint. `Resource::Web#mime_for` still
answered `"page"` — the last of the kind vocabulary anywhere in the app.

A mirror is only as fresh as the last save, so `Resource.restate!` exists for the case where a
declaration changes in code and the rows do not. Nothing calls it but the migration; when a
`serves` line changes, that is the thing to run.

## Phase 6a — a mime type is a feed

- [x] `Feed::MIME`, a fifth type, singleton on `(tenant, type, key)` like a tag and an address
- [x] `Feed.mime!`, `Feed.mimed`, the `mimes` scope and `Feed#mimes` beside their tag twins
- [x] The pass files a feed under `Feed.mime!(mime)` rather than `Feed.tag!(mime)`
- [x] `FeedType.mimes` and the `feed` tool report them apart from tags
- [x] The migration sweeps the mechanically-minted mime tags and their edges

**Phase 6a landed 2026-09-08.** 784 runs, 0 failures. `feed.tags` is now what a person or an
agent filed, and nothing else — the mime no longer pads the `tags` keyword facet or the
`tags^2` full-text field. The `mime` column on the reference stays: it is what `Analyzer.for`
dispatches on, what `Resource#accepts` matches, and what the search facet reads. The feed is
derived from the column rather than replacing it.

The migration deletes `uris:tag` rows whose key contains a slash. That is a heuristic — a
hand-made tag with a slash would go with them — but every slashed tag in existence was minted
by `filed`, and the plan has been greenfield since phase 0.

## Phase 7 — the upload lane

- [ ] `active_storage:install`; the service is `Disk` locally and S3 where web and worker are
      separate containers
- [ ] `POST /uploads` attaches and returns; the pass analyzes the attachment; the agent picks a
      resource; a reference is recorded and the attachment purged
- [ ] `Intake.write!` stops uploading to `default_storage` inside the request
- [ ] Preview and thumbnail become stored references with roles, generated once, rather than
      `Thumbnail` rendering on read into `Rails.cache`
- [ ] Active Storage's three tables carry no RLS — isolation reaches them only through the
      attachment's owner, so `tenant_isolation_test.rb` needs the case
- [ ] Turn off the public redirect controllers; bytes are served through `content_controller`

## Phase 8 — the surface

- [ ] `codegen` and `web/schema.graphql` regenerated
- [ ] The SPA: `/items/:id` → `/feeds/:id`, the kind facet becomes a tag facet, `--k-*` custom
      properties key off the tag rather than a column
- [ ] `RunTrail` and the feed page read analyses; `analysisProgressed` replaces `agentTurned`
- [ ] A page for a `uris:tag` — its members are the whole render

## Phase 9 — finishing

- [ ] `docs/` regenerated; the drift-check script walks the new registries
- [ ] Squash every migration into one initial migration
- [ ] `bin/ci` green

## Deferred

- **Merge, and the proposals that fed it.** Removed 2026-09-08 rather than carried: `merge!`,
  `MergeProposal`, `Blocking`, `ProposeMergesJob`, three mutations, the `merges` page and the
  `merge_proposals` query. Nothing about the collapse needs it, and a proposal that says two
  feeds are one thing is a question about identity that `(type, key)` has not been asked yet.
  `Reference#move_to!` and `#split!` stay — a reference moving between feeds is what sync and
  export already do, and a merge was only ever a loop over that.
- **`split_reference` is a mutation with nothing to undo.** A feed only ends up with two
  references through a merge, so the button is unreachable until merge comes back. Kept
  because the model operation underneath it is not merge's.

## Known gaps, recorded rather than fixed

- **`SearchIndex.document` asks for a feed's tags one query at a time**, so a full reindex is
  still one extra query per feed. It wants a join, or a batch lookup threaded through
  `index_all` — which is machinery, so it stays recorded. The family half of this is fixed:
  `body_text`, `summaries` and `keywords` walked `[self] + children` and asked each one for
  `analyses.settled.last`, three times over, and `Analysis` was queried even when the
  association was already loaded. A feed with twenty children cost 64 queries to index and now
  costs 10, guarded by `test/unit/models/indexing_queries_test.rb`.
- **An edge does not yet re-analyze the feed on the other side.** The `edge` cause exists and
  nothing raises it, pending the cooldown decision above.
- **`Schedule#create_schedule!` does not set `next_run_at`** — only `SaveFeed` does, so a schedule
  made any other way never becomes due. Phase 5 works around it in a test rather than fixing it.
- **A feed with no reference has no `analyzed_at`.** It reads the references, which is what the
  analyzer stamps, so an address shows nothing where the SPA used to show a time. What an
  address wants is its last analysis's `finished_at`, which is a phase 8 decision about what
  the page shows rather than a model one.
- **The mime facet is filterable but nothing offers it.** `SearchIndex` takes `mime:` and `tag:`
  now, and `Feed.search` passes them, but no GraphQL argument and no tool exposes either.
  Phase 8 turns the kind facet into a tag facet and can spend them then. `FeedType.mimes` and
  the `feed` tool's `mimes` are the connection-side answer; the search argument is still absent.
