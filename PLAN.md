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

- [ ] `Resource::OpenaiCompatible#check!` probes the declared `agent` model with one
      tool-call round trip, not just `GET /v1/models`
- [ ] `check_resource` reports the endpoint answers **and** the model chains
- [ ] A resource whose `agent` model cannot chain is `check_error`, not silently fine
- [ ] Seed the three local backends as commented examples: ollama `:11434`,
      LM Studio `:1234`, mlx `:8082`
- [ ] `bin/probe-agent` stays a hand-run diagnostic; nothing in the app calls it

## Phase 1 — the loop, with no Feed anywhere

- [ ] `#converse(messages:, tools:)` on the inference resource — one turn, tool-aware
- [ ] It must not send `response_format: json_object`, which fights tool calling
- [ ] An `Agent` that loops: turn cap, dispatches through the same `Tool.call` MCP uses,
      appends `role: "tool"` messages
- [ ] One `Prompt` row per turn, `promptable:` the run
- [ ] Exercised against `search_items` and `get_item` only, with a real `Grant`
- [ ] Done when a rake task runs a sentence against a live tenant and chains two real tools

## Phase 2 — Feed as a record

- [ ] `Feed`: tenant, slug, prompt, role, schedule
- [ ] `Run::KINDS` gains `feed`, so `halted?`, cancellation, gates and budgets come free
- [ ] `Feed#run!` → `Run` → `AgentJob`
- [ ] `Feed::TURNS` cap; running out is a normal outcome rather than an error

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
