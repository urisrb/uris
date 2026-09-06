import {
  Alert,
  Button,
  Group,
  Loader,
  Modal,
  NumberInput,
  Stack,
  Table,
  Text,
  Textarea,
  TextInput,
} from '@mantine/core'
import {
  FeedsDocument,
  PauseFeedDocument,
  RunFeedDocument,
  SaveFeedDocument,
} from '@uris-to/client'
import { useMutation, useQuery } from '@uris-to/client/react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

const EVERY = [
  { label: 'by hand', seconds: 0 },
  { label: 'hourly', seconds: 3600 },
  { label: 'daily', seconds: 86400 },
  { label: 'weekly', seconds: 604800 },
]

function cadence(interval?: number | null, pausedAt?: string | null) {
  if (pausedAt) return 'paused'
  if (!interval) return 'by hand'

  return (
    EVERY.find((option) => option.seconds === interval)?.label ??
    `every ${Math.round(interval / 60)}m`
  )
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

export function Feeds() {
  const { data, loading, error, refetch } = useQuery(FeedsDocument, {})
  const save = useMutation(SaveFeedDocument)
  const start = useMutation(RunFeedDocument)
  const pause = useMutation(PauseFeedDocument)

  const [open, setOpen] = useState(false)
  const [slug, setSlug] = useState('')
  const [prompt, setPrompt] = useState('')
  const [interval, setInterval] = useState<number>(0)
  const [refused, setRefused] = useState<string | null>(null)

  const feeds = data?.feeds ?? []

  useEffect(() => {
    if (!open) return

    setSlug('')
    setPrompt('')
    setInterval(0)
    setRefused(null)
  }, [open])

  async function create() {
    const answered = await save.execute({ slug, prompt, interval })

    if (!answered) {
      setRefused(save.error?.message ?? 'That feed could not be saved.')
      return
    }

    setOpen(false)
    refetch()
  }

  return (
    <Stack gap="var(--s5)">
      <Group justify="space-between" align="flex-end">
        <div>
          <h1 className="page-title">Feeds</h1>
          <div className="eyebrow" style={{ marginTop: 'var(--s2)' }}>
            A prompt with an address. It searches your catalog and keeps what it
            finds.
          </div>
        </div>

        <Button onClick={() => setOpen(true)}>New feed</Button>
      </Group>

      {error && <Alert color="red">{error.message}</Alert>}

      {loading && feeds.length === 0 && <Loader size="sm" />}

      {!loading && feeds.length === 0 && (
        <div className="panel" style={{ padding: 'var(--s6)' }}>
          <Text c="dimmed" size="sm">
            No feeds yet. One is a sentence and a name — <code>/buy</code>,
            &ldquo;find things worth buying from my stores&rdquo;.
          </Text>
        </div>
      )}

      {feeds.length > 0 && (
        <div className="panel">
          <Table verticalSpacing="sm" horizontalSpacing="lg">
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Feed</Table.Th>
                <Table.Th>Items</Table.Th>
                <Table.Th>Runs</Table.Th>
                <Table.Th>Last</Table.Th>
                <Table.Th>Next</Table.Th>
                <Table.Th />
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {feeds.map((feed) => (
                <Table.Tr key={feed.id}>
                  <Table.Td>
                    <Link to={`/feeds/${feed.slug}`} className="plain">
                      <Text fw={600} size="sm">
                        /{feed.slug}
                      </Text>
                    </Link>
                    <Text c="dimmed" size="xs" lineClamp={1}>
                      {feed.prompt}
                    </Text>
                  </Table.Td>
                  <Table.Td>{feed.itemsCount}</Table.Td>
                  <Table.Td>
                    <span className="tag" data-dot="false">
                      {cadence(feed.interval, feed.pausedAt)}
                    </span>
                  </Table.Td>
                  <Table.Td>
                    <Text size="xs" c="dimmed">
                      {when(feed.ranAt)}
                    </Text>
                  </Table.Td>
                  <Table.Td>
                    <Text size="xs" c="dimmed">
                      {when(feed.nextRunAt)}
                    </Text>
                  </Table.Td>
                  <Table.Td>
                    <Group gap="var(--s2)" justify="flex-end">
                      <Button
                        size="compact-xs"
                        variant="default"
                        onClick={async () => {
                          await start.execute({ id: feed.id })
                          refetch()
                        }}
                      >
                        Run
                      </Button>
                      {feed.interval ? (
                        <Button
                          size="compact-xs"
                          variant="subtle"
                          onClick={async () => {
                            await pause.execute({
                              id: feed.id,
                              paused: !feed.pausedAt,
                            })
                            refetch()
                          }}
                        >
                          {feed.pausedAt ? 'Resume' : 'Pause'}
                        </Button>
                      ) : null}
                    </Group>
                  </Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        </div>
      )}

      <Modal opened={open} onClose={() => setOpen(false)} title="New feed">
        <Stack gap="var(--s4)">
          <TextInput
            label="Address"
            description="It becomes a path. Letters, numbers and dashes."
            placeholder="buy"
            value={slug}
            onChange={(event) => setSlug(event.currentTarget.value)}
          />

          <Textarea
            label="Prompt"
            description="What it should go and find, in a sentence."
            placeholder="Find things worth buying from my stores."
            autosize
            minRows={3}
            value={prompt}
            onChange={(event) => setPrompt(event.currentTarget.value)}
          />

          <div>
            <Text size="sm" fw={500}>
              Runs
            </Text>
            <Group gap="var(--s2)" mt="var(--s2)">
              {EVERY.map((option) => (
                <button
                  key={option.label}
                  type="button"
                  className="tag"
                  data-dot="false"
                  data-on={interval === option.seconds}
                  style={{ cursor: 'pointer' }}
                  onClick={() => setInterval(option.seconds)}
                >
                  {option.label}
                </button>
              ))}
            </Group>
          </div>

          {interval > 0 && (
            <NumberInput
              label="Seconds between runs"
              min={60}
              value={interval}
              onChange={(value) => setInterval(Number(value) || 0)}
            />
          )}

          {refused && <Alert color="red">{refused}</Alert>}

          <Group justify="flex-end">
            <Button variant="default" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={create} disabled={!slug || !prompt}>
              Create
            </Button>
          </Group>
        </Stack>
      </Modal>
    </Stack>
  )
}
