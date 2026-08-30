import { graphql } from '../generated'

// The tenant comes back from the server, resolved from the subdomain. The SPA
// never sends it — a client-supplied tenant is a client-chosen tenant.
export const CatalogQuery = graphql(`
  query Catalog {
    tenant {
      id
      name
      subdomain
    }
    things {
      id
      kind
      title
      createdAt
    }
  }
`)

export const ThingChangedSubscription = graphql(`
  subscription ThingChanged {
    thingChanged {
      thing {
        id
        kind
        title
        createdAt
      }
    }
  }
`)
