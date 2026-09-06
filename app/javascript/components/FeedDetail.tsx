import { Alert, Button, Group, Loader, Stack, Table, Text } from '@mantine/core'
import {
  IconPencil,
  IconPlayerPause,
  IconPlayerPlay,
  IconRefresh,
  IconTrash,
} from '@tabler/icons-react'
import {
  AgentTurnedDocument,
  DeleteFeedDocument,
  FeedDocument,
  PauseFeedDocument,
  RunFeedDocument,
  RunProgressedDocument,
} from '@uris-to/client'
import { useQuery, useSubscription } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useTitle } from '../hooks/useTitle'
import { tone } from '../kinds'
import { FeedForm } from './FeedForm'
import { RunTrail } from './RunTrail'
import { useAloud, useSay } from './Say'
import { Sure } from './Sure'

const OPEN = new Set(['queued', 'running'])

interface Turn {
  turn: number
  calls: string[]
  said?: string | null
}

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
  const navigate = useNavigate()
  const say = useSay()
  const [editing, setEditing] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const { data, loading, error, refetch } = useQuery(FeedDocument, {
    slug: slug ?? '',
  })
  const start = useAloud(RunFeedDocument, 'That feed could not be run.')
  const pause = useAloud(PauseFeedDocument, 'That feed could not be paused.')
  const remove = useAloud(DeleteFeedDocument, 'That feed could not be deleted.')

  const feed = data?.feed
  const runs = feed?.runs ?? []
  const items = feed?.items ?? []
  const open = runs.find((run) => OPEN.has(run.status))

  useTitle(feed ? `/${feed.slug}` : 'Feed')

  const { data: progressed } = useSubscription(RunProgressedDocument)
  const streamed = progressed?.runProgressed.run

  useEffect(() => {
    if (!streamed) return
    if (!runs.some((run) => run.id === streamed.id)) return

    refetch()
  }, [streamed, runs, refetch])

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
          {open && <Loader size="xs" />}

          <Button
            variant="subtle"
            color="gray"
            radius="xl"
            leftSection={<IconTrash size={15} />}
            onClick={() => setDeleting(true)}
          >
            Delete
          </Button>

          <Button
            variant="subtle"
            color="gray"
            radius="xl"
            leftSection={<IconPencil size={15} />}
            onClick={() => setEditing(true)}
          >
            Edit
          </Button>

          {feed.interval ? (
            <Button
              variant="default"
              radius="xl"
              loading={pause.loading}
              leftSection={
                feed.pausedAt ? (
                  <IconPlayerPlay size={15} />
                ) : (
                  <IconPlayerPause size={15} />
                )
              }
              onClick={async () => {
                const answered = await pause.execute({
                  id: feed.id,
                  paused: !feed.pausedAt,
                })

                if (!answered) return

                say({
                  text: feed.pausedAt
                    ? `/${feed.slug} runs on its own again.`
                    : `/${feed.slug} is paused. It will only run by hand.`,
                })
                refetch()
              }}
            >
              {feed.pausedAt ? 'Resume' : 'Pause'}
            </Button>
          ) : null}

          <Button
            radius="xl"
            color="chalk"
            loading={start.loading}
            disabled={Boolean(open)}
            leftSection={<IconRefresh size={15} />}
            onClick={async () => {
              const answered = await start.execute({ id: feed.id })

              if (!answered) return

              say({ text: `/${feed.slug} is running.` })
              refetch()
            }}
          >
            {open ? 'Running' : 'Run now'}
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
        <div>
          <div className="eyebrow">Turns it may take</div>
          <Text fw={600}>{feed.turns ?? 'the default'}</Text>
        </div>
      </Group>

      <Sure
        opened={deleting}
        onClose={() => setDeleting(false)}
        title={`Delete /${feed.slug}?`}
        verb="Delete it"
        loading={remove.loading}
        onSure={async () => {
          const answered = await remove.execute({ id: feed.id })

          if (!answered) return

          const kept = answered.deleteFeed?.kept ?? 0

          setDeleting(false)
          say({
            text: kept
              ? `/${feed.slug} is gone. The ${kept} ${kept === 1 ? 'item' : 'items'} it wrote stayed in your catalog.`
              : `/${feed.slug} is gone.`,
          })
          navigate('/feeds')
        }}
      >
        The prompt and its run history go. Anything it wrote stays in your
        catalog as an ordinary item — deleting the feed that found something is
        not the same as throwing the something away.
      </Sure>

      <FeedForm
        opened={editing}
        onClose={() => setEditing(false)}
        feed={feed}
        onSaved={(saved) => {
          say({ text: `/${saved} is saved.` })

          if (saved === feed.slug) refetch()
          else navigate(`/feeds/${saved}`, { replace: true })
        }}
      />

      {open && <Thinking key={open.id} id={open.id} cap={feed.turns} />}

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

function Thinking({ id, cap }: { id: string; cap?: number | null }) {
  const [turns, setTurns] = useState<Turn[]>([])
  const { data } = useSubscription(AgentTurnedDocument, { id })

  useEffect(() => {
    const turn = data?.agentTurned

    if (!turn) return

    setTurns((held) =>
      held.some((past) => past.turn === turn.turn) ? held : [...held, turn],
    )
  }, [data])

  const latest = turns[turns.length - 1]

  return (
    <div className="thinking">
      <div className="thinking-head">
        <span className="thinking-pulse" />
        <span className="label">Thinking</span>
        <span className="eyebrow">
          turn <span className="figure">{latest?.turn ?? 1}</span>
          {cap ? (
            <>
              {' '}
              of <span className="figure">{cap}</span>
            </>
          ) : null}
        </span>
      </div>

      {turns.length === 0 ? (
        <Text size="sm" c="dimmed" px="var(--s4)" pb="var(--s4)">
          Waiting on the first turn. What it reasons through will show up here
          as it goes.
        </Text>
      ) : (
        <div className="thinking-turns">
          {turns.map((turn) => (
            <div key={turn.turn} className="thinking-turn">
              <span className="thinking-count figure">{turn.turn}</span>

              <div style={{ minWidth: 0 }}>
                {turn.said && <div className="thinking-said">{turn.said}</div>}

                {turn.calls.length > 0 && (
                  <Group gap="var(--s2)" mt="var(--s2)">
                    {turn.calls.map((call) => (
                      <span
                        key={call}
                        className="tag mono"
                        style={{ '--tone': 'var(--brass)' } as CSSProperties}
                      >
                        {call}
                      </span>
                    ))}
                  </Group>
                )}

                {!turn.said && turn.calls.length === 0 && (
                  <Text size="xs" c="dimmed">
                    thought without saying anything
                  </Text>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
