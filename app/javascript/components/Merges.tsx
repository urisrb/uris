import { Alert, Button, Group, Loader, Stack, Text } from '@mantine/core'
import { IconArrowMerge, IconScan, IconX } from '@tabler/icons-react'
import {
  MergeProposalsDocument,
  ProposeMergesDocument,
  SettleMergeProposalDocument,
} from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { type CSSProperties, useState } from 'react'
import { Link } from 'react-router-dom'
import { usePages } from '../hooks/usePages'
import { useTitle } from '../hooks/useTitle'
import { tone } from '../kinds'
import { useAloud, useSay } from './Say'
import { Thumb } from './Thumb'

const PAGE = 20

const STATUSES = ['open', 'accepted', 'rejected', 'stale']

const TONES: Record<string, string> = {
  open: 'var(--brass)',
  accepted: 'var(--ok)',
  rejected: 'var(--edge)',
  stale: 'var(--muted)',
}

const BECAUSE: Record<string, string> = {
  'same-name': 'they go by the same name',
  'same-bytes': 'they are byte for byte the same',
}

interface Reference {
  id: string
  filename: string
  contentType: string
  resource: { id: string; key: string; type: string }
}

interface Item {
  id: string
  kind: string
  title?: string | null
  summary?: string | null
  thumbnailUrl?: string | null
  createdAt: string
  references: Reference[]
}

interface Proposal {
  id: string
  blockingKey: string
  reason: string
  status: string
  current: boolean
  settledAt?: string | null
  createdAt: string
  items: Item[]
}

function when(at: string) {
  return new Date(at).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

function where(item: Item) {
  const keys = [...new Set(item.references.map((one) => one.resource.key))]

  if (keys.length === 0) return 'nowhere'
  if (keys.length <= 2) return keys.join(' and ')

  return `${keys.slice(0, 2).join(', ')} and ${keys.length - 2} more`
}

export function Merges() {
  useTitle('Duplicates')

  const say = useSay()
  const [status, setStatus] = useState('open')
  const look = useAloud(ProposeMergesDocument, 'That search could not start.')

  return (
    <Stack gap="var(--s5)">
      <Group justify="space-between" align="flex-start">
        <div>
          <h1 className="page-title">Duplicates</h1>
          <div
            className="eyebrow"
            style={{ marginTop: 'var(--s2)', maxWidth: '62ch' }}
          >
            Items that look like the same thing. Merging gathers every place
            they live onto the oldest of them — nothing is thrown away, and a
            place can always be split back off.
          </div>
        </div>

        <Button
          radius="xl"
          variant="default"
          loading={look.loading}
          leftSection={<IconScan size={16} stroke={1.7} />}
          onClick={async () => {
            const answered = await look.execute({})

            if (!answered) return

            say({
              text: 'Looking through the catalog. Anything it finds turns up here.',
            })
          }}
        >
          Look again
        </Button>
      </Group>

      <Group gap="var(--s2)">
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
            data-off={status !== value}
            onClick={() => setStatus(value)}
          >
            {value}
          </button>
        ))}
      </Group>

      <Queue key={status} status={status} />
    </Stack>
  )
}

function Queue({ status }: { status: string }) {
  const [cursor, setCursor] = useState<string | null>(null)

  const { data, loading, error } = useQuery(MergeProposalsDocument, {
    status,
    after: cursor,
    limit: PAGE,
  })

  const page = data?.mergeProposals
  const [kept, setKept] = usePages<Proposal>(
    page as { nodes: Proposal[] } | undefined,
    cursor,
  )

  const settle = (id: string) =>
    setKept((held) => held.filter((one) => one.id !== id))

  if (error) return <Alert color="red">{error.message}</Alert>
  if (loading && kept.length === 0) {
    return <Loader size="sm" color="var(--brass)" />
  }

  if (kept.length === 0) {
    return (
      <Text c="dimmed" size="sm" maw="58ch">
        {status === 'open'
          ? 'Nothing looks like a duplicate. Look again after a sync and uris will check the catalog over.'
          : `Nothing has been ${status}.`}
      </Text>
    )
  }

  return (
    <Stack gap="var(--s4)">
      {kept.map((proposal) => (
        <Pair key={proposal.id} proposal={proposal} onSettled={settle} />
      ))}

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

function Pair({
  proposal,
  onSettled,
}: {
  proposal: Proposal
  onSettled: (id: string) => void
}) {
  const say = useSay()
  const settle = useAloud(
    SettleMergeProposalDocument,
    'That could not be settled.',
  )

  const settled = proposal.status !== 'open'

  const answer = async (accept: boolean) => {
    const answered = await settle.execute({ id: proposal.id, accept })

    if (!answered) return

    say({
      text: accept
        ? `${proposal.items.length} items are one now — ${answered.settleMergeProposal?.item?.title ?? 'it'} holds all of them.`
        : 'Left alone. uris will not ask about these again.',
    })
    onSettled(proposal.id)
  }

  return (
    <div className="merge">
      <div className="merge-head">
        <Group gap="var(--s2)" wrap="wrap">
          <span
            className="tag"
            style={{ '--tone': TONES[proposal.status] } as CSSProperties}
          >
            {proposal.status}
          </span>
          <Text size="sm" fw={600}>
            <span className="figure">{proposal.items.length}</span> items,{' '}
            {BECAUSE[proposal.reason] ?? proposal.reason}
          </Text>
          <Text size="xs" c="dimmed">
            found {when(proposal.createdAt)}
          </Text>
        </Group>

        {!settled && proposal.current && (
          <Group gap="var(--s2)" wrap="nowrap">
            <Button
              size="xs"
              radius="xl"
              variant="subtle"
              color="gray"
              leftSection={<IconX size={14} />}
              loading={settle.loading}
              onClick={() => answer(false)}
            >
              Leave them
            </Button>
            <Button
              size="xs"
              radius="xl"
              color="chalk"
              leftSection={<IconArrowMerge size={14} />}
              loading={settle.loading}
              onClick={() => answer(true)}
            >
              Merge them
            </Button>
          </Group>
        )}

        {!settled && !proposal.current && (
          <Button
            size="xs"
            radius="xl"
            variant="subtle"
            color="gray"
            loading={settle.loading}
            onClick={() => answer(false)}
          >
            Dismiss
          </Button>
        )}
      </div>

      {!proposal.current && !settled && (
        <Text
          size="xs"
          px="var(--s4)"
          pb="var(--s3)"
          style={{ color: 'var(--bad)' }}
        >
          One of these has moved or been merged since uris noticed them, so this
          is no longer a fair comparison. Dismiss it and look again.
        </Text>
      )}

      <div className="merge-items">
        {proposal.items.map((item, at) => (
          <Link
            key={item.id}
            to={`/items/${item.id}`}
            className="merge-item"
            data-keeps={at === 0 && !settled}
          >
            <Thumb
              url={item.thumbnailUrl}
              kind={item.kind}
              alt={item.title ?? ''}
              size={44}
            />

            <div style={{ minWidth: 0 }}>
              <div className="entry-title">{item.title ?? 'Untitled'}</div>

              <Group gap="var(--s2)" mt="var(--s2)" wrap="wrap">
                <span
                  className="tag"
                  style={{ '--tone': tone(item.kind) } as CSSProperties}
                >
                  {item.kind}
                </span>
                {at === 0 && !settled && (
                  <span className="tag" data-dot="false">
                    the others join this one
                  </span>
                )}
              </Group>

              <Text size="xs" c="dimmed" mt="var(--s2)">
                kept {when(item.createdAt)} · lives in {where(item)}
              </Text>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
