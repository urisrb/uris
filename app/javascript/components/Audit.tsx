import { Alert, Button, Code, Group, Loader, Stack, Text } from '@mantine/core'
import { IconSearch } from '@tabler/icons-react'
import { AuditEventsDocument } from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { usePages } from '../hooks/usePages'
import { useTitle } from '../hooks/useTitle'

const PAGE = 50

const STATUSES = ['ok', 'denied', 'error']

const TONES: Record<string, string> = {
  ok: 'var(--ok)',
  denied: 'var(--brass)',
  error: 'var(--bad)',
}

const READING: Record<string, string> = {
  ok: 'allowed',
  denied: 'refused',
  error: 'failed',
}

interface Event {
  id: string
  channel: string
  action: string
  status: string
  scope?: string | null
  subject?: string | null
  clientId?: string | null
  remoteIp?: string | null
  requestId?: string | null
  durationMs?: number | null
  detail?: string | null
  arguments: Record<string, unknown>
  createdAt: string
  run?: { id: string; kind: string; status: string } | null
}

function ago(at: string) {
  const seconds = Math.round((Date.now() - new Date(at).getTime()) / 1000)

  if (seconds < 60) return 'just now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`

  return `${Math.floor(seconds / 86400)}d ago`
}

function who(event: Event) {
  return event.subject ?? event.clientId ?? 'nobody signed in'
}

export function Audit() {
  useTitle('Activity')

  const [status, setStatus] = useState<string | null>(null)
  const [subject, setSubject] = useState('')
  const [asking, setAsking] = useState('')

  return (
    <Stack gap="var(--s5)">
      <div className="eyebrow">
        Every privileged thing anyone asked uris to do, whether it was allowed,
        and what it was asked with. Newest first.
      </div>

      <Group gap="var(--s3)" align="center" wrap="wrap">
        <Group gap="var(--s2)">
          <button
            type="button"
            className="tag"
            data-dot="false"
            data-on={status === null}
            aria-pressed={status === null}
            style={{ cursor: 'pointer' }}
            onClick={() => setStatus(null)}
          >
            everything
          </button>
          {STATUSES.map((value) => (
            <button
              key={value}
              type="button"
              className="tag"
              style={
                { '--tone': TONES[value], cursor: 'pointer' } as CSSProperties
              }
              data-on={status === value}
              aria-pressed={status === value}
              data-off={status !== null && status !== value}
              onClick={() => setStatus(status === value ? null : value)}
            >
              {READING[value]}
            </button>
          ))}
        </Group>

        <form
          className="sift"
          onSubmit={(event) => {
            event.preventDefault()
            setSubject(asking.trim())
          }}
        >
          <IconSearch size={15} stroke={1.8} color="var(--muted)" />
          <input
            value={asking}
            onChange={(event) => setAsking(event.currentTarget.value)}
            placeholder="Narrow to one subject"
            aria-label="Narrow to one subject"
          />
          {subject && (
            <Button
              variant="subtle"
              color="gray"
              size="compact-xs"
              onClick={() => {
                setAsking('')
                setSubject('')
              }}
            >
              Clear
            </Button>
          )}
        </form>
      </Group>

      <Trail
        key={`${status ?? ''} ${subject}`}
        status={status}
        subject={subject}
      />
    </Stack>
  )
}

function Trail({
  status,
  subject,
}: {
  status: string | null
  subject: string
}) {
  const [cursor, setCursor] = useState<string | null>(null)
  const [open, setOpen] = useState<string | null>(null)
  const [, tick] = useState(0)

  // "3m ago" is only true for a minute, and this page is one people leave open.
  useEffect(() => {
    const timer = window.setInterval(() => tick((count) => count + 1), 30_000)

    return () => window.clearInterval(timer)
  }, [])

  const { data, loading, error } = useQuery(AuditEventsDocument, {
    action: null,
    status,
    subject: subject || null,
    after: cursor,
    limit: PAGE,
  })

  const page = data?.auditEvents
  const [kept] = usePages<Event>(page as { nodes: Event[] } | undefined, cursor)

  if (error) return <Alert color="red">{error.message}</Alert>
  if (loading && kept.length === 0)
    return <Loader size="sm" color="var(--brass)" />

  if (kept.length === 0) {
    return (
      <Text c="dimmed" size="sm">
        {status || subject
          ? 'Nothing matches that.'
          : 'Nothing has been asked of uris yet. Sync a resource or point a client at /mcp and it will fill up.'}
      </Text>
    )
  }

  return (
    <Stack gap="var(--s4)">
      <div className="panel">
        {kept.map((event) => (
          <div
            key={event.id}
            className="entry"
            data-spine="true"
            style={
              {
                '--tone': TONES[event.status] ?? 'var(--edge)',
              } as CSSProperties
            }
          >
            <div style={{ minWidth: 0 }}>
              <Group gap="var(--s2)" wrap="wrap">
                <span className="entry-title mono">{event.action}</span>
                <span className="tag" data-dot="false">
                  {event.channel}
                </span>
                <span
                  className="tag"
                  style={
                    {
                      '--tone': TONES[event.status] ?? 'var(--edge)',
                    } as CSSProperties
                  }
                >
                  {READING[event.status] ?? event.status}
                </span>
                {event.scope && (
                  <span className="tag mono" data-dot="false">
                    {event.scope}
                  </span>
                )}
              </Group>

              <Text size="xs" c="dimmed" mt="var(--s2)">
                {who(event)}
                {event.remoteIp ? ` · ${event.remoteIp}` : ''}
                {typeof event.durationMs === 'number'
                  ? ` · ${event.durationMs}ms`
                  : ''}
              </Text>

              {event.detail && (
                <Text
                  size="xs"
                  mt="var(--s1)"
                  style={{
                    color: event.status === 'ok' ? 'var(--soft)' : 'var(--bad)',
                  }}
                >
                  {event.detail}
                </Text>
              )}

              {open === event.id && (
                <Stack gap="var(--s2)" mt="var(--s3)">
                  {Object.keys(event.arguments ?? {}).length > 0 && (
                    <Code block className="fallen-why">
                      {JSON.stringify(event.arguments, null, 2)}
                    </Code>
                  )}

                  <Text size="xs" c="dimmed" className="mono">
                    {new Date(event.createdAt).toLocaleString()}
                    {event.clientId ? ` · client ${event.clientId}` : ''}
                    {event.requestId ? ` · request ${event.requestId}` : ''}
                  </Text>

                  {event.run && (
                    <Link to="/settings/runs" className="plain">
                      <Text size="xs" style={{ color: 'var(--brass)' }}>
                        opened a {event.run.kind} run — {event.run.status}
                      </Text>
                    </Link>
                  )}
                </Stack>
              )}
            </div>

            <Group gap="var(--s3)" wrap="nowrap" align="center">
              <Text size="xs" c="dimmed" className="figure">
                {ago(event.createdAt)}
              </Text>
              <button
                type="button"
                className="tag"
                data-dot="false"
                data-on={open === event.id}
                aria-expanded={open === event.id}
                style={{ cursor: 'pointer' }}
                onClick={() => setOpen(open === event.id ? null : event.id)}
              >
                {open === event.id ? 'hide' : 'why'}
              </button>
            </Group>
          </div>
        ))}
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
