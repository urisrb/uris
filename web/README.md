# @uris-to/client

A GraphQL and Action Cable client for [uris](https://uris.pages.dev), an indexer for personal data.
It is built on [urql](https://github.com/urql-graphql/urql) and ships typed documents for every
operation the uris browser app uses.

## Installation

```sh
npm install @uris-to/client
```

`graphql` is a required peer dependency. `react` and `@rails/actioncable` are optional peer
dependencies. Install them only if you import `@uris-to/client/react` or
`@uris-to/client/actioncable`.

## Usage

`createUris` returns a urql `Client` that posts JSON to the GraphQL endpoint:

```ts
import { createUris, metaCSRFToken } from "@uris-to/client";
import { actionCableExchange } from "@uris-to/client/actioncable";

export const client = createUris({
  url: "/graphql",
  csrfToken: metaCSRFToken,
  onUnauthorized: () => signIn(),
  subscriptions: actionCableExchange(),
});
```

Run a typed document with the client:

```ts
import { SettingsDocument } from "@uris-to/client";

const { data, error } = await client.query(SettingsDocument, {}).toPromise();
```

### React

```tsx
import { UrisProvider, useQuery } from "@uris-to/client/react";
import { SettingsDocument } from "@uris-to/client";

<UrisProvider client={client}>
  <App />
</UrisProvider>;

function Settings() {
  const { data, loading, error } = useQuery(SettingsDocument);

  if (loading) return <p>Loading</p>;
  if (error) return <p>{error.message}</p>;
  return <pre>{JSON.stringify(data, null, 2)}</pre>;
}
```

## API

### `@uris-to/client`

| | |
| --- | --- |
| `createUris(options)` | Returns a `UrisClient`, which is a urql `Client`. |
| `metaCSRFToken()` | Returns the `content` of the page's `<meta name="csrf-token">` tag, or `null`. |
| `UrisClient` | The client type. |
| `UrisOptions` | The options for `createUris`. |
| `*Document` | A typed document for each query, mutation, and subscription, such as `CatalogDocument`, `SearchDocument`, and `AttachResourceDocument`. |

The package also exports the TypeScript types generated from the uris GraphQL schema, including the
result and variables types for each document.

`UrisOptions` has these fields:

| | |
| --- | --- |
| `url` | The GraphQL endpoint. Required. |
| `csrfToken` | A function that returns the CSRF token, sent as the `X-CSRF-Token` header on every request. |
| `onUnauthorized` | Called when a request returns a 401 response. |
| `subscriptions` | A urql exchange for subscriptions, such as the one `actionCableExchange` returns. |

The client uses urql's document cache.

### `@uris-to/client/react`

| | |
| --- | --- |
| `UrisProvider` | Puts a client in React context. |
| `useUris()` | Returns the client from context. Throws outside a `UrisProvider`. |
| `useQuery(document, variables?, { skip? })` | Runs the query from the network whenever the variables change. Returns `{ data, loading, error, refetch }`. |
| `useMutation(document)` | Returns `{ execute, attempt, loading, error }`. `execute(variables)` resolves to the data or `null`. `attempt(variables)` resolves to `{ data, error }`. |
| `useSubscription(document, variables?, { skip? })` | Subscribes while mounted. Returns `{ data, error }` with the latest result. |

### `@uris-to/client/actioncable`

| | |
| --- | --- |
| `actionCableExchange({ channel?, url? })` | Returns a urql subscription exchange over Action Cable. `channel` defaults to `GraphqlChannel`. Without a `url`, the consumer reads the page's `action-cable-url` meta tag, or connects to `/cable`. |

## Development

The types come from the schema of the uris Rails app, so the package is built from a checkout of
[the uris repository](https://github.com/urisrb/uris):

```sh
bin/rails graphql:dump_schema
npm run codegen
npm run build:sdk
```

`graphql:dump_schema` writes `web/schema.graphql`, `codegen` generates
`web/src/generated/graphql.ts` from it and the operations in `web/src/operations`, and `build:sdk`
compiles the package into `web/dist`.

## License

MIT.
