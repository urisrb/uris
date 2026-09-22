# uris

uris is an indexer for personal data. It reads the places your files and records live, builds one
searchable index across all of them with analysis attached, and can return the bytes as an export
or a local copy.

The documentation is at <https://uris.pages.dev>:

| | |
| --- | --- |
| [Overview](https://uris.pages.dev/overview/) | What uris is and the key concepts |
| [Quickstart](https://uris.pages.dev/quickstart/) | Run uris locally, connect it to masks, and add the first file |
| How-to guides | Single tasks, such as [attaching a resource](https://uris.pages.dev/guides/attach-a-resource/) |
| Key concepts | How each part works, starting with [feeds](https://uris.pages.dev/concepts/feeds/) |
| Reference | Generated from the code, such as the [GraphQL schema](https://uris.pages.dev/reference/graphql/) |

## Running uris

`./dev` needs Docker and nothing else.

```sh
./dev
```

This builds and starts Rails, Vite, the worker, the documentation site, and three backing services
(PostgreSQL, OpenSearch, and MinIO) in containers, all with live reloading. One tenant answers at
<http://uris.localhost:8180>, and the documentation is at <http://uris.localhost:8181>. You do not
need to edit `/etc/hosts`, because `*.localhost` resolves to the loopback address.

Sign-in goes through [masks](https://github.com/urisrb/masks). `MASKS_ISSUER` names the masks
server, and it has to be running for sign-in to complete. From a masks checkout beside this one, run
`../masks/dev`.

To run two tenants, `demo` and `acme`, the way a real deployment does, pass `--multi`:

```sh
./dev --multi
```

The tenants answer at <http://demo.uris.localhost:8180> and <http://acme.uris.localhost:8180>.

Inference runs on the host GPU. The stack connects to Ollama on `host.docker.internal`, so run
`brew bundle` to install Ollama and the other tools in the `Brewfile` if you want the analyzers to
have a model.

Run `./dev help` for the other commands, such as `./dev console`, `./dev logs`, and `./dev reset`.

## Testing

```sh
./dev test
```

This runs the `unit`, `server`, `corpus`, and `client` suites in the containers. Name a suite to run
only that one, for example `./dev test server`. The Rails suites clear `URIS_TENANT` and
`URIS_TENANTS`, so they run against multiple tenants whichever way the stack was started. CI runs
each suite the same way.

## Interfaces

uris has two interfaces over one domain layer:

| Path | Client | Authorization |
| --- | --- | --- |
| `/graphql` | The browser app, built with urql, generated types, and Action Cable subscriptions | A masks session |
| `/mcp` | An MCP client, such as Claude | A masks token, with typed tools and per-token grants |

Neither interface wraps the other. uris does not expose GraphQL as an MCP tool, because a single
passthrough tool cannot be partially granted.

The Ruby schema is the source of truth, and the TypeScript types are generated from it. If the
single-page app drifts from the API, the type check fails. `./dev` runs both watchers. The generated
client is published to npm as [`@uris-to/client`](web/README.md).

## Resources

A resource is a place uris reads from or writes to. Some resources point at files. The `github`,
`notion`, and `slack` types catalog records that have no file of their own, such as an issue, a
page, or a thread. uris composes text for each record so that it is searchable beside a PDF.

The five API resource types (`github`, `notion`, `slack`, `oauth-google`, and `microsoft-graph`)
share one adapter, `Resource::Api`. The adapter makes the HTTPS request, checks that the host
matches the service, caps the response size, retries once after a 401 when the token has expired,
and raises a failure on a 429 that the job retries with backoff. Each subclass defines where its
pages come from and how a record reads as text.

The adapter asks the resource for a token. Types that act as a person on another service include
`Resource::Delegated`, which gets that token from masks.

Jobs that touch an unbounded number of records, such as a sync or an export, use
[job-iteration](https://github.com/Shopify/job-iteration). They save a cursor as they go and resume
from it after a deploy.

## Configuration

Nothing in this repository names a host, a domain, or a secret. Those belong to a deployment, which
keeps them in its own infrastructure repository. uris reads all of them from the environment, and
`.env.example` documents each variable. The
[environment reference](https://uris.pages.dev/reference/environment/) lists them as well.

## History

The schema was rewritten in September 2026. The old prose was removed at that time, and it remains
in the git history. The current behavior is described in the documentation, whose reference pages
are generated from the code. `PLAN.md` holds the plan in progress.
