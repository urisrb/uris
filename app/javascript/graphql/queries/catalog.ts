import { graphql } from '../generated'

export const CatalogQuery = graphql(`
  query Catalog {
    tenant {
      id
      name
      subdomain
    }
    resources {
      id
      type
      key
      name
      capabilities
      thingsCount
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
