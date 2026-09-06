import { Alert, Button, Group, Loader, Stack, Table, Text } from '@mantine/core'
import { FeedDocument, RunFeedDocument } from '@uris-to/client'
import { useMutation, useQuery } from '@uris-to/client/react'
import { type CSSProperties, useEffect } from 'react'
import { Link, useParams } from 'react-router-dom'
import { tone } from '../kinds'
import { RunTrail } from './RunTrail'

const OPEN = new Set(['queued', 'running'])

function when(at?: string | null) {
  if (!at) return '—'

  return new Date(at).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

export function FeedDetail() {
  const { slug } = useParams<{ slug: string }>()
  const { data, loading, error, refetch } = useQuery(FeedDocument, {
    slug: slug ?? '',
  })
  const start = useMutation(RunFeedDocument)

  const feed = data?.feed
  const runs = feed?.runs ?? []
  const items = feed?.items ?? []
  const busy = runs.some((run) => OPEN.has(run.status))

  useEffect(() => {
    if (!busy) return

    const timer = window.setInterval(() => refetch(), 2000)

    return () => window.clearInterval(timer)
  }, [busy, refetch])

  if (loading && !feed) return <Loader size="sm" />
  if (error) return <Alert color="red">{error.message}</Alert>
  if (!feed) return <Alert color="yellow">No feed at /{slug}.</Alert>

  return (
    <Stack gap="var(--s5)">
      <Group justify="space-between" align="flex-end">
        <div>
          <Link to="/feeds" className="eyebrow plain">
            Feeds
          </Link>
          <h1 className="page-title" style={{ marginTop: 'var(--s2)' }}>
            /{feed.slug}
          </h1>
          <Text c="dimmed" size="sm" mt="var(--s2)" maw="60ch">
            {feed.prompt}
          </Text>
        </div>

        <Group gap="var(--s2)">
          {busy && <Loader size="xs" />}
          <Button
            onClick={async () => {
              await start.execute({ id: feed.id })
              refetch()
            }}
          >
            Run now
          </Button>
        </Group>
      </Group>

      <Group gap="var(--s5)">
        <div>
          <div className="eyebrow">Items</div>
          <Text fw={600}>{feed.itemsCount}</Text>
        </div>
        <div>
          <div className="eyebrow">Last run</div>
          <Text fw={600}>{when(feed.ranAt)}</Text>
        </div>
        <div>
          <div className="eyebrow">Next</div>
          <Text fw={600}>
            {feed.pausedAt ? 'paused' : when(feed.nextRunAt)}
          </Text>
        </div>
      </Group>

      {items.length > 0 && (
        <div className="panel">
          <Table verticalSpacing="sm" horizontalSpacing="lg">
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Item</Table.Th>
                <Table.Th>Kind</Table.Th>
                <Table.Th>Where it came from</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {items.map((item) => (
                <Table.Tr key={item.id}>
                  <Table.Td>
                    <Link to={`/items/${item.id}`} className="plain">
                      <Text size="sm">{item.title}</Text>
                    </Link>
                  </Table.Td>
                  <Table.Td>
                    <span
                      className="tag"
                      style={{ '--tone': tone(item.kind) } as CSSProperties}
                    >
                      {item.kind}
                    </span>
                  </Table.Td>
                  <Table.Td>
                    <Text size="xs" c="dimmed">
                      {item.origin === 'feed'
                        ? 'written by this feed'
                        : 'synced from a resource'}
                    </Text>
                  </Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        </div>
      )}

      {items.length === 0 && (
        <div className="panel" style={{ padding: 'var(--s6)' }}>
          <Text c="dimmed" size="sm">
            Nothing kept yet. Run it and it will search your catalog.
          </Text>
        </div>
      )}

      <div>
        <div className="eyebrow" style={{ marginBottom: 'var(--s3)' }}>
          Runs
        </div>
        <RunTrail feedId={feed.id} empty="This feed has not run yet." />
      </div>
    </Stack>
  )
}
