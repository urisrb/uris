import { Alert, Button, Group, Loader, Stack, Table, Text } from '@mantine/core'
import {
  CancelRunDocument,
  RunProgressedDocument,
  RunsDocument,
} from '@uris-to/client'
import { useQuery, useSubscription } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useState } from 'react'
import { useTitle } from '../hooks/useTitle'
import { RUN_OPEN, RUN_TONES, RunLog } from './RunTrail'
import { useAloud, useSay } from './Say'

const PAGE = 50

const STATUSES = ['queued', 'running', 'done', 'failed', 'cancelled', 'gated']

interface Row {
  id: string
  kind: string
  status: string
  processed: number
  lines: number
  error?: string | null
  startedAt?: string | null
  finishedAt?: string | null
  createdAt: string
  resource?: { id: string; key: string } | null
}

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
  useTitle('Runs')

  const [status, setStatus] = useState<string | null>(null)

  return (
    <Stack gap="var(--s5)">
      <div>
        <h1 className="page-title">Runs</h1>
        <div className="eyebrow" style={{ marginTop: 'var(--s2)' }}>
          Work that outlives a single request. Anything still open reports
          itself as it goes.
        </div>
      </div>

      <Group gap="var(--s2)">
        <button
          type="button"
          className="tag"
          data-dot="false"
          data-on={status === null}
          style={{ cursor: 'pointer' }}
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
              { '--tone': RUN_TONES[value], cursor: 'pointer' } as CSSProperties
            }
            data-on={status === value}
            data-off={status !== null && status !== value}
            onClick={() => setStatus(status === value ? null : value)}
          >
            {value}
          </button>
        ))}
      </Group>

      <Ledger key={status ?? ''} status={status} />
    </Stack>
  )
}

function Ledger({ status }: { status: string | null }) {
  const say = useSay()
  const [cursor, setCursor] = useState<string | null>(null)
  const [rows, setRows] = useState<Row[]>([])
  const [open, setOpen] = useState<string | null>(null)
  const [, tick] = useState(0)

  const { data, loading, error, refetch } = useQuery(RunsDocument, {
    status,
    after: cursor,
    limit: PAGE,
  })
  const cancel = useAloud(CancelRunDocument, 'That run could not be cancelled.')
  const { data: progressed } = useSubscription(RunProgressedDocument)

  const streamed = progressed?.runProgressed.run
  const live = streamed?.id === open ? (streamed?.logs ?? null) : null
  const busy = rows.some((run) => RUN_OPEN.has(run.status))

  useEffect(() => {
    const page = data?.runs
    if (!page) return

    setRows((held) =>
      cursor ? [...held, ...(page.nodes as Row[])] : [...(page.nodes as Row[])],
    )
  }, [data, cursor])

  useEffect(() => {
    if (!streamed) return

    setRows((held) => {
      const at = held.findIndex((run) => run.id === streamed.id)

      if (at < 0) return held

      const next = [...held]

      next[at] = {
        ...next[at],
        status: streamed.status,
        processed: streamed.processed,
        lines: streamed.lines,
        startedAt: streamed.startedAt,
        finishedAt: streamed.finishedAt,
      }

      return next
    })
  }, [streamed])

  useEffect(() => {
    if (!streamed || cursor) return
    if (rows.some((run) => run.id === streamed.id)) return

    refetch()
  }, [streamed, cursor, rows, refetch])

  useEffect(() => {
    if (!busy) return

    const timer = window.setInterval(() => tick((count) => count + 1), 1000)

    return () => window.clearInterval(timer)
  }, [busy])

  const page = data?.runs

  if (error) return <Alert color="red">{error.message}</Alert>
  if (loading && rows.length === 0) {
    return <Loader size="sm" color="var(--brass)" />
  }

  if (rows.length === 0) {
    return (
      <Text c="dimmed" size="sm">
        {status
          ? `Nothing is ${status}.`
          : 'Nothing has run yet. Sync a resource and it will show up here.'}
      </Text>
    )
  }

  return (
    <Stack gap="var(--s4)">
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
            {rows.flatMap((run) => [
              <Table.Tr key={run.id}>
                <Table.Td>
                  <Group gap="var(--s2)" wrap="nowrap">
                    {run.lines > 0 && (
                      <button
                        type="button"
                        className="tag"
                        data-dot="false"
                        data-on={open === run.id}
                        style={{ cursor: 'pointer' }}
                        onClick={() => setOpen(open === run.id ? null : run.id)}
                      >
                        {open === run.id ? 'hide' : `${run.lines} lines`}
                      </button>
                    )}
                    <Text fw={600} size="sm">
                      {run.kind}
                    </Text>
                  </Group>
                  {run.error && (
                    <Text size="xs" style={{ color: 'var(--bad)' }}>
                      {run.error}
                    </Text>
                  )}
                </Table.Td>
                <Table.Td>
                  <span
                    className="tag"
                    style={
                      {
                        '--tone': RUN_TONES[run.status] ?? 'var(--edge)',
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
                  {RUN_OPEN.has(run.status) && (
                    <Button
                      size="compact-xs"
                      radius="xl"
                      variant="subtle"
                      color="red"
                      onClick={async () => {
                        const answered = await cancel.execute({ id: run.id })

                        if (!answered) return

                        const settled =
                          answered.cancelRun?.run.status ?? 'cancelled'

                        setRows((held) =>
                          held.map((row) =>
                            row.id === run.id
                              ? { ...row, status: settled }
                              : row,
                          ),
                        )
                        say({ text: `The ${run.kind} run was cancelled.` })
                      }}
                    >
                      Cancel
                    </Button>
                  )}
                </Table.Td>
              </Table.Tr>,
              open === run.id ? (
                <Table.Tr key={`${run.id}-log`}>
                  <Table.Td colSpan={6} style={{ paddingTop: 0 }}>
                    <RunLog id={run.id} live={live} />
                  </Table.Td>
                </Table.Tr>
              ) : null,
            ])}
          </Table.Tbody>
        </Table>
      </div>

      {page?.hasMore && (
        <Group justify="center">
          <Button
            variant="default"
            radius="xl"
            loading={loading}
            onClick={() => setCursor(page.nextCursor ?? null)}
          >
            Load more
          </Button>
        </Group>
      )}
    </Stack>
  )
}
