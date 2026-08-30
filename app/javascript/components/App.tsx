import { useEffect } from 'react'
import {
  CatalogQuery,
  ThingAnalyzedSubscription,
} from '../graphql/queries/catalog'
import { useQuery, useSubscription } from '../hooks/useGraphQL'

export function App() {
  const { data, loading, error, refetch } = useQuery(CatalogQuery)
  const { data: analyzed } = useSubscription(ThingAnalyzedSubscription)

  useEffect(() => {
    if (analyzed) refetch()
  }, [analyzed, refetch])

  if (loading) return <p>Loading…</p>
  if (error) return <p>{error.message}</p>
  if (!data?.tenant) return <p>Unknown tenant.</p>

  return (
    <main>
      <h1>{data.tenant.name}</h1>

      <h2>Resources</h2>
      <ul>
        {data.resources.map((resource) => (
          <li key={resource.id}>
            <strong>{resource.type}</strong> {resource.key} —{' '}
            {resource.thingsCount} things
          </li>
        ))}
      </ul>

      <h2>Things</h2>
      <ul>
        {data.things.map((thing) => (
          <li key={thing.id}>
            <strong>{thing.kind}</strong> — {thing.title}
          </li>
        ))}
      </ul>
    </main>
  )
}
