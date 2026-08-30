import { graphql } from '../generated'

export const CatalogQuery = graphql(`
  query Catalog($kind: String, $after: ID, $limit: Int) {
    tenant {
      id
      name
      subdomain
    }
    kinds {
      kind
      count
    }
    things(kind: $kind, after: $after, limit: $limit) {
      hasMore
      nextCursor
      nodes {
        id
        kind
        title
        summary
        thumbnailUrl
        analyzedAt
        createdAt
      }
    }
  }
`)

export const SearchQuery = graphql(`
  query Search($query: String, $kind: String) {
    search(query: $query, kind: $kind) {
      id
      kind
      title
      summary
      thumbnailUrl
      analyzedAt
      createdAt
    }
  }
`)

export const ThingQuery = graphql(`
  query Thing($id: ID!) {
    thing(id: $id) {
      id
      kind
      title
      summary
      thumbnailUrl
      analyzedAt
      createdAt
      references {
        id
        locatorKey
        filename
        contentType
        contentUrl
        thumbnailUrl
        analyzedAt
        analysis
        resource {
          id
          key
          type
        }
      }
    }
  }
`)

export const ResourcesQuery = graphql(`
  query Resources {
    resources {
      id
      type
      key
      name
      capabilities
      thingsCount
      defaultStorage
      syncInterval
      nextSyncAt
      syncedAt
      syncing
      checkedAt
      checkError
      healthy
    }
  }
`)

export const RunsQuery = graphql(`
  query Runs($status: String, $after: ID, $limit: Int) {
    runs(status: $status, after: $after, limit: $limit) {
      hasMore
      nextCursor
      nodes {
        id
        kind
        status
        processed
        error
        startedAt
        finishedAt
        createdAt
        resource {
          id
          key
        }
      }
    }
  }
`)

export const ThingAnalyzedSubscription = graphql(`
  subscription ThingAnalyzed {
    thingAnalyzed {
      thing {
        id
        kind
        title
      }
    }
  }
`)

export const AnalyzeThingMutation = graphql(`
  mutation AnalyzeThing($id: ID!) {
    analyzeThing(input: { id: $id }) {
      run {
        id
        status
      }
    }
  }
`)

export const SplitReferenceMutation = graphql(`
  mutation SplitReference($id: ID!) {
    splitReference(input: { id: $id }) {
      thing {
        id
      }
    }
  }
`)

export const SyncResourceMutation = graphql(`
  mutation SyncResource($id: ID!) {
    syncResource(input: { id: $id }) {
      run {
        id
        status
      }
      resource {
        id
        syncing
      }
    }
  }
`)

export const CheckResourceMutation = graphql(`
  mutation CheckResource($id: ID!) {
    checkResource(input: { id: $id }) {
      ok
      resource {
        id
        checkedAt
        checkError
        healthy
      }
    }
  }
`)

export const SetDefaultStorageMutation = graphql(`
  mutation SetDefaultStorage($id: ID!) {
    setDefaultStorage(input: { id: $id }) {
      resource {
        id
        defaultStorage
      }
    }
  }
`)

export const SetSyncIntervalMutation = graphql(`
  mutation SetSyncInterval($id: ID!, $seconds: Int) {
    setSyncInterval(input: { id: $id, seconds: $seconds }) {
      resource {
        id
        syncInterval
        nextSyncAt
      }
    }
  }
`)

export const ExportThingsMutation = graphql(`
  mutation ExportThings($destinationId: ID, $kind: String, $query: String) {
    exportThings(
      input: { destinationId: $destinationId, kind: $kind, query: $query }
    ) {
      run {
        id
        status
      }
    }
  }
`)

export const CancelRunMutation = graphql(`
  mutation CancelRun($id: ID!) {
    cancelRun(input: { id: $id }) {
      cancelled
      run {
        id
        status
      }
    }
  }
`)
