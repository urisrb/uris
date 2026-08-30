import { useEffect } from 'react'
import {
  CatalogQuery,
  ThingChangedSubscription,
} from '../graphql/queries/catalog'
import { useQuery, useSubscription } from '../hooks/useGraphQL'

export function App() {
  const { data, loading, error, refetch } = useQuery(CatalogQuery)
  const { data: changed } = useSubscription(ThingChangedSubscription)

  // Everything this product does is long-running, so the catalog is pushed at
  // the browser rather than polled for. This is the same channel that will
  // carry analysis-step and run progress.
  useEffect(() => {
    if (changed) refetch()
  }, [changed, refetch])

  if (loading) return <p>Loading…</p>
  if (error) return <p>{error.message}</p>
  if (!data?.tenant) return <p>Unknown tenant.</p>

  return (
    <main>
      <h1>{data.tenant.name}</h1>
      <p>{data.tenant.subdomain}</p>

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
