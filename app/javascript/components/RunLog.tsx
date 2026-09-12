import { Loader, Text } from '@mantine/core'
import { RunLogDocument } from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { useEffect, useRef } from 'react'

export const RUN_TONES: Record<string, string> = {
  queued: 'var(--edge)',
  running: 'var(--busy)',
  done: 'var(--ok)',
  failed: 'var(--bad)',
  cancelled: 'var(--edge)',
  gated: 'var(--brass)',
}

export const RUN_OPEN = new Set(['queued', 'running'])

export const TONE_FOR_LINE: Record<string, string> = {
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
