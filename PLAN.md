# Feeds

A feed is a prompt with an address. `demo.uris.to/buy` holds a sentence, and running it
produces items you can search like anything else in the catalog.

Written 2026-09-06. Ordered by dependency: each phase is usable on its own and the one
after it assumes the one before landed.

Background and the measurements behind the model choice: `docs/src/content/docs/concepts/feeds.mdx`.

## Decisions still open

- [ ] **Are feeds ever public?** Changes whether the catch-all serves anonymous requests, and
      collides with using `uris.to/<code>` for short links.
- [ ] **Default `agent` model.** `openai/gpt-oss-20b` on LM Studio was cleanest of the six that
      passed; `qwen3:8b` on ollama is one less runtime to keep alive.
- [x] **The write phase is ours.** The model is offered read tools only. Decided 2026-09-06.
- [x] **Items are both selected and minted, with provenance.** Decided 2026-09-06.

## Phase 0 — verification you can trust

Everything after this assumes we can tell whether a declared model actually works. This
would have caught `glm4` on its own.

- [x] `Resource::OpenaiCompatible#check!` probes the declared `agent` model over two turns,
      not just `GET /v1/models`
- [x] `check_resource` reports the endpoint answers **and** the model chains
- [x] A resource whose `agent` model cannot chain is `check_error`, not silently fine
- [x] Measured: refuses `glm4`, passes `qwen3:8b`, `llama3.1:8b` and `gpt-oss-20b`. It is a
      floor, not a ceiling — one synthetic tool catches a model that cannot call tools at
      all, and misses one that degrades against the real eleven. `bin/probe-agent` stays
      the acceptance test
- [x] Seed declares an `agent` role, and documents LM Studio `:1234` and mlx `:8082` as the
      other backends, each a row with its own `base_url`
- [x] `bin/probe-agent` stays a hand-run diagnostic; nothing in the app calls it

**Phase 0 landed 2026-09-06.** 479 runs, 0 failures.

## Phase 1 — the loop, with no Feed anywhere

- [x] `#converse(messages:, tools:)` on the inference resource — one turn, tool-aware
- [x] It must not send `response_format: json_object`, which fights tool calling
- [x] An `Agent` that loops: turn cap, dispatches through the same `Tool.call` MCP uses,
      appends `role: "tool"` messages
- [x] One `Prompt` row per turn, `promptable:` the run, recording the reasoning too
- [x] `agentTurned` subscription, alongside `itemAnalyzed`, scoped by tenant
- [x] Exercised against `search_items` and `get_item` only, with a real `Grant`
- [x] `rake agent:ask[demo,'…']` chains search_items then get_item and answers from real items

**Phase 1 landed 2026-09-06.** A thinking model spends its budget reasoning before it emits
anything, so agent turns get 4096 tokens rather than 1024 — at 1024 qwen3 ran out mid-thought
and returned neither content nor a call. That case now raises rather than looking like a model
that chose to stop.

## Phase 2 — Feed as a record

- [x] `Feed`: tenant, slug, prompt, role, turns
- [x] `Run::KINDS` gains `feed`, and a run points back at the feed that opened it
- [x] `Feed#run!` → `Run` → `RunFeedJob`
- [x] `Feed::TURNS` cap; running out finishes the run with a reason rather than raising
- [x] Reserved slugs refused at the model, not left to route order
- [x] A feed acts as itself — `feed:<slug>` — rather than borrowing whoever opened the page
- [ ] Feeds on a schedule (moved to Later)

**Phase 2 landed 2026-09-06.** `/invoices` ran in 4 turns and answered $4,200 from real items.
`RunFeedJob` owns its `Run` directly rather than through `TrackedRun`, whose hooks come from
JobIteration and a feed is one unit of work rather than an iteration.

## Phase 3 — results, with provenance

- [ ] `origin` on `Item`: `resource` when synced, `feed` when minted
- [ ] Minted items live in a `feeds` `Resource::Database`, carrying `feed_id` and `run_id`
- [ ] A join so a feed has its selections
- [ ] Nothing lets a feed rewrite a synced item's origin

## Phase 4 — the write phase is ours

- [ ] The model is offered read tools only: `search_items`, `get_item`
- [ ] `add_to_feed` and `create_item` are called by our code after the read phase returns
- [ ] A feed cannot `sync_resource` or `export_items` whatever it emits — not offered,
      not merely refused. Scope stays the backstop rather than the only guard

## Phase 5 — addressing

- [ ] Catch-all route declared **last**
- [ ] Slug validated against what the app already owns: `mcp`, `graphql`, `graphiql`, `auth`,
      `enroll`, `references`, `jobs`, `up`, `settings`, `resources`, `runs`
- [ ] `feeds#show` renders the feed's items

## Later, separately

- [ ] `Resource::Tailscale` implementing `reach!`. `OpenaiCompatible#base_url` already asks
      `via.reach!`, so nothing else changes — and it is the real answer to running a model
      too big for this laptop
- [ ] Feeds on an interval, the way a resource holds `sync_interval`
