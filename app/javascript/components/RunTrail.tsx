import { Group, Loader, Table, Text } from '@mantine/core'
import {
  ContextRunsDocument,
  RunLogDocument,
  RunProgressedDocument,
} from '@uris-to/client'
import { useQuery, useSubscription } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useRef, useState } from 'react'

export const RUN_TONES: Record<string, string> = {
  queued: 'var(--edge)',
  running: 'var(--busy)',
  done: 'var(--ok)',
  failed: 'var(--bad)',
  cancelled: 'var(--edge)',
  gated: 'var(--brass)',
}

export const RUN_OPEN = new Set(['queued', 'running'])

const TONE_FOR_LINE: Record<string, string> = {
  '[x]': 'var(--bad)',
  '[✓]': 'var(--ok)',
  '[-]': 'var(--muted)',
}

export function RunLog({ id, live }: { id: string; live: string | null }) {
  const { data, loading } = useQuery(RunLogDocument, { id })
  const bottom = useRef<HTMLDivElement | null>(null)
  const logs = live ?? data?.run?.logs ?? ''
  const lines = logs.split('\n').filter(Boolean)
  const written = lines.length

  useEffect(() => {
    if (written === 0) return

    bottom.current?.scrollIntoView({ block: 'nearest' })
  }, [written])

  if (loading && !data) return <Loader size="xs" color="var(--brass)" />

  if (written === 0) {
    return (
      <Text c="dimmed" size="xs">
        This kind of work does not log.
      </Text>
    )
  }

  return (
    <div className="run-log">
      {lines.map((line, index) => (
        <div
          // biome-ignore lint/suspicious/noArrayIndexKey: position is the identity
          key={index}
          style={{ color: TONE_FOR_LINE[line.slice(0, 3)] ?? 'var(--soft)' }}
        >
          {line}
        </div>
      ))}
      <div ref={bottom} />
    </div>
  )
}

function when(value?: string | null) {
  return value ? new Date(value).toLocaleString() : '—'
}

// The runs behind whatever you are already looking at. Feeds own theirs
// through a column; analysis names its item in the selector.
export function RunTrail({
  feedId,
  itemId,
  empty,
}: {
  feedId?: string
  itemId?: string
  empty: string
}) {
  const [open, setOpen] = useState<string | null>(null)
  const [stranger, setStranger] = useState<string | null>(null)
  const { data, loading, refetch } = useQuery(ContextRunsDocument, {
    feedId: feedId ?? null,
    itemId: itemId ?? null,
    limit: 20,
  })
  const { data: progressed } = useSubscription(RunProgressedDocument)

  const rows = data?.runs.nodes ?? []

  const streamed = progressed?.runProgressed.run
  const live = streamed?.id === open ? (streamed?.logs ?? null) : null

  useEffect(() => {
    if (!streamed) return

    const ours = rows.some((run) => run.id === streamed.id)

    if (!ours && stranger === streamed.id) return

    if (!ours) setStranger(streamed.id)

    refetch()
  }, [streamed, rows, stranger, refetch])

  if (loading && !data) return <Loader size="xs" color="var(--brass)" />

  if (rows.length === 0) {
    return (
      <Text c="dimmed" size="sm">
        {empty}
      </Text>
    )
  }

  return (
    <div className="panel">
      <Table verticalSpacing="xs" horizontalSpacing="lg">
        <Table.Tbody>
          {rows.flatMap((run) => [
            <Table.Tr key={run.id}>
              <Table.Td width="1%">
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
                <Group gap="var(--s2)" wrap="nowrap">
                  <Text size="xs" fw={600}>
                    {run.kind}
                  </Text>
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
                </Group>
              </Table.Td>
              <Table.Td>
                <Text size="xs" c="dimmed">
                  {when(run.createdAt)}
                </Text>
              </Table.Td>
              <Table.Td>
                {run.error && (
                  <Text size="xs" style={{ color: 'var(--bad)' }}>
                    {run.error}
                  </Text>
                )}
              </Table.Td>
            </Table.Tr>,
            open === run.id ? (
              <Table.Tr key={`${run.id}-log`}>
                <Table.Td colSpan={4} style={{ paddingTop: 0 }}>
                  <RunLog id={run.id} live={live} />
                </Table.Td>
              </Table.Tr>
            ) : null,
          ])}
        </Table.Tbody>
      </Table>
    </div>
  )
}
