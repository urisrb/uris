# uris

A data unifier — one searchable index across everything you own, wherever it lives, with a way back
out.

Drive search only searches Drive. Gmail search only searches Gmail. uris searches across all of
them, with analysis attached, and can hand the bytes back as an export or a local copy.

Not every type points at files. `github`, `notion` and `slack` catalogue records that were never
bytes — an issue, a page, a thread — and compose the text they never had, so they are searchable
beside a PDF. All five API types sit on one adapter owning the dialling, the host check, the byte
cap, the 401 worth one more attempt and the 429 worth retrying; a subclass writes where its pages
come from and what a record reads like, and nothing else. That adapter does not know which of them
is brokered — it asks the resource for a token, and `Resource::Brokered` is where the answer
changes.

Everything that touches an unbounded number of things checkpoints through
[job-iteration](https://github.com/Shopify/job-iteration), so a sync or an export survives a deploy
and resumes at its cursor rather than starting over.

## Running it

```sh
./dev                # the whole stack, in containers, reloading
./dev test           # unit, server, corpus and client, in containers
```

`./dev` needs docker and nothing else. It runs Rails, vite, the worker, the doc site and the three
backing services, all reloading, and one tenant answers at <http://uris.localhost:8180> with its
docs on <http://uris.localhost:8181>. Nothing goes in `/etc/hosts`: `*.localhost` already resolves.

Sign-in goes through masks, which `MASKS_ISSUER` names and which has to be running for the handshake
to complete — `../masks/dev`, or both at once with `home/dev`.

`./dev --multi` declares `demo` and `acme` instead and serves them at
<http://demo.uris.localhost:8180>, which is what the suite exercises and what a real deployment
looks like.

Inference still runs on the host GPU: the stack reaches an Ollama on `host.docker.internal`, so
`brew bundle` is worth running if you want the analyzers to have a model to talk to.

## Two interfaces, one domain layer

```
browser  → /graphql   session auth, first-party client, urql + codegen + cable subscriptions
Claude   → /mcp       typed tools, token-scoped grants
```

Neither wraps the other. Exposing GraphQL _as_ an MCP tool is what would collapse them back into
one — a single passthrough tool cannot be partially granted.

The Ruby schema is the source of truth and the TypeScript is generated from it, so the SPA cannot
drift from the API without the types going red first. `./dev` keeps both watchers running.

## The boundary rule

**Nothing in this repo may name a host, a domain, or a secret.** Those are facts about a deployment,
and they belong in the private infrastructure repo that consumes this one. Everything arrives
through the environment; `.env.example` documents what.

## What is not written down yet

The schema underneath uris was rewritten in September 2026 — one record for a thing, one record for
a pass over it — and the prose that described the old shape was removed rather than patched. What
went, and why, is in `PLAN.md`; what it said is in the history.

Gone from here: the four movements, the item/resource vocabulary, how search fuses two rankings, the
four layers of tenant isolation, the twelve-tool endpoint table, snapshots and the SSRF containment
around them, and the two-pool job policy. Each of those described something real and most of it
still holds — but each also carried a claim that no longer does, and a README nobody can trust is
worse than a short one.
