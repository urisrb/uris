# @uris-to/client

A GraphQL and Action Cable client for [uris](https://uris.pages.dev).

```sh
npm install @uris-to/client
```

The schema is the Ruby app's, dumped and generated against, so the typed
documents in here always match the API they were built from.

```ts
import { createUris } from "@uris-to/client";

export const client = createUris({
  url: "/graphql",
  fetchOptions: { headers: { "X-CSRF-Token": metaCSRFToken() } },
});
```

## React

```tsx
import { UrisProvider, useUris } from "@uris-to/client/react";

<UrisProvider client={client}>
  <App />
</UrisProvider>;
```

`useUris()` returns the client from context, and throws outside a provider.

## Subscriptions

```ts
import { cable } from "@uris-to/client/actioncable";
```

Action Cable is an optional peer dependency, as is React. Install them only if
you use them.

MIT.
