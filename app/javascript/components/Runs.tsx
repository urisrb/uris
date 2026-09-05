import { Alert, Button, Group, Loader, Stack, Table, Text } from '@mantine/core'
import { CancelRunDocument, RunsDocument } from '@thingies/client'
import { useMutation, useQuery } from '@thingies/client/react'
import { type CSSProperties, useEffect, useState } from 'react'

const STATUSES = ['queued', 'running', 'done', 'failed', 'cancelled', 'gated']

const TONES: Record<string, string> = {
  queued: 'var(--k-file)',
  running: 'var(--k-text)',
  done: 'var(--k-data)',
  failed: 'var(--k-pdf)',
  cancelled: 'var(--k-email)',
  gated: 'var(--k-image)',
}

const OPEN = new Set(['queued', 'running'])

function elapsed(startedAt?: string | null, finishedAt?: string | null) {
  if (!startedAt) return '—'

  const from = new Date(startedAt).getTime()
  const to = finishedAt ? new Date(finishedAt).getTime() : Date.now()
  const seconds = Math.max(0, Math.round((to - from) / 1000))

  return seconds < 60
    ? `${seconds}s`
    : `${Math.floor(seconds / 60)}m ${seconds % 60}s`
}

export function Runs() {
  const [status, setStatus] = useState<string | null>(null)
  const { data, loading, error, refetch } = useQuery(RunsDocument, {
    status,
    after: null,
    limit: 50,
  })
  const cancel = useMutation(CancelRunDocument)

  const rows = data?.runs.nodes ?? []
  const busy = rows.some((run) => OPEN.has(run.status))

  useEffect(() => {
    if (!busy) return

    const timer = window.setInterval(() => refetch(), 2000)

    return () => window.clearInterval(timer)
  }, [busy, refetch])

  return (
    <Stack gap={22}>
      <div>
        <h1
          className="wordmark"
          style={{ fontSize: 'clamp(1.9rem, 4vw, 2.6rem)', margin: 0 }}
        >
          Runs
        </h1>
        <div className="eyebrow" style={{ marginTop: 8 }}>
          Work that outlives a single request. Anything still open refreshes
          itself.
        </div>
      </div>

      <Group gap={8}>
        <button
          type="button"
          className="tag"
          style={
            { '--tone': 'var(--edge)', cursor: 'pointer' } as CSSProperties
          }
          data-on={status === null}
          onClick={() => setStatus(null)}
        >
          all
        </button>
        {STATUSES.map((value) => (
          <button
            key={value}
            type="button"
            className="tag"
            style={
              {
                '--tone': TONES[value],
                cursor: 'pointer',
                opacity: status === null || status === value ? 1 : 0.45,
              } as CSSProperties
            }
            onClick={() => setStatus(status === value ? null : value)}
          >
            {value}
          </button>
        ))}
      </Group>

      {error && <Alert color="red">{error.message}</Alert>}

      {rows.length > 0 && (
        <div className="panel">
          <Table verticalSpacing="sm" horizontalSpacing="lg">
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Work</Table.Th>
                <Table.Th>Status</Table.Th>
                <Table.Th>Resource</Table.Th>
                <Table.Th>Processed</Table.Th>
                <Table.Th>Elapsed</Table.Th>
                <Table.Th />
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {rows.map((run) => (
                <Table.Tr key={run.id}>
                  <Table.Td>
                    <Text fw={600} size="sm">
                      {run.kind}
                    </Text>
                    {run.error && (
                      <Text size="xs" style={{ color: 'var(--k-pdf)' }}>
                        {run.error}
                      </Text>
                    )}
                  </Table.Td>
                  <Table.Td>
                    <span
                      className="tag"
                      style={
                        {
                          '--tone': TONES[run.status] ?? 'var(--k-file)',
                        } as CSSProperties
                      }
                    >
                      {run.status}
                    </span>
                  </Table.Td>
                  <Table.Td>
                    <Text size="sm" c="dimmed">
                      {run.resource?.key ?? '—'}
                    </Text>
                  </Table.Td>
                  <Table.Td>
                    <span className="figure">
                      {run.processed.toLocaleString()}
                    </span>
                  </Table.Td>
                  <Table.Td>
                    <span className="figure" style={{ color: 'var(--muted)' }}>
                      {elapsed(run.startedAt, run.finishedAt)}
                    </span>
                  </Table.Td>
                  <Table.Td>
                    {OPEN.has(run.status) && (
                      <Button
                        size="compact-xs"
                        radius="xl"
                        variant="subtle"
                        color="red"
                        onClick={async () => {
                          await cancel.execute({ id: run.id })
                          refetch()
                        }}
                      >
                        Cancel
                      </Button>
                    )}
                  </Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        </div>
      )}

      {loading && !data && <Loader size="sm" color="var(--brass)" />}

      {!loading && rows.length === 0 && (
        <Text c="dimmed" size="sm">
          {status
            ? `Nothing is ${status}.`
            : 'Nothing has run yet. Sync a resource and it will show up here.'}
        </Text>
      )}
    </Stack>
  )
}
