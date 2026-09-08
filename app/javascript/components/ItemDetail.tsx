import {
  Alert,
  Button,
  Group,
  Loader,
  Stack,
  Text,
  Textarea,
} from '@mantine/core'
import {
  IconArrowLeft,
  IconCut,
  IconEraser,
  IconNote,
  IconPencil,
  IconSparkles,
} from '@tabler/icons-react'
import {
  AnalyzeFeedDocument,
  FeedDetailDocument,
  ForgetFeedDocument,
  NoteFeedDocument,
  RenameFeedDocument,
  SplitReferenceDocument,
} from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useTitle } from '../hooks/useTitle'
import { KindBadge } from './KindBadge'
import { RunTrail } from './RunTrail'
import { useAloud, useSay } from './Say'
import { Sure } from './Sure'
import { Thumb } from './Thumb'

export function ItemDetail() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const say = useSay()
  const [forgetting, setForgetting] = useState(false)
  const { data, loading, error, refetch } = useQuery(FeedDetailDocument, { id })
  const analyze = useAloud(
    AnalyzeFeedDocument,
    'That item could not be analyzed.',
  )
  const split = useAloud(
    SplitReferenceDocument,
    'That place could not be split off.',
  )
  const forget = useAloud(
    ForgetFeedDocument,
    'That item could not be forgotten.',
  )
  const rename = useAloud(RenameFeedDocument, 'That name could not be kept.')
  const note = useAloud(NoteFeedDocument, 'That note could not be kept.')

  const item = data?.feed

  useTitle(item?.title ?? 'Item')

  if (loading && !data) return <Loader size="sm" color="var(--brass)" />
  if (error) return <Alert color="red">{error.message}</Alert>

  if (!item) return <Text c="dimmed">No such item.</Text>

  const viewable = item.references.filter((reference) =>
    /^(image|application\/pdf)/.test(reference.contentType),
  )

  return (
    <Stack gap="var(--s5)">
      <Button
        component={Link}
        to="/"
        variant="subtle"
        color="gray"
        size="compact-sm"
        w="fit-content"
        leftSection={<IconArrowLeft size={15} />}
      >
        Catalog
      </Button>

      <Group justify="space-between" align="flex-start" wrap="nowrap">
        <div style={{ minWidth: 0, flex: 1 }}>
          <Naming
            title={item.title ?? ''}
            busy={rename.loading}
            onName={async (next) => {
              const answered = await rename.execute({
                id: item.id,
                title: next,
              })

              if (!answered) return false

              refetch()
              return true
            }}
          />
          <Group gap="var(--s3)" mt="var(--s3)">
            <KindBadge kind={item.type} />
            <span className="eyebrow">
              <span className="figure">{item.references.length}</span>{' '}
              {item.references.length === 1 ? 'place' : 'places'} it lives
              {item.analyzedAt
                ? ` · analyzed ${new Date(item.analyzedAt).toLocaleString()}`
                : ' · never analyzed'}
            </span>
          </Group>
        </div>

        <Group gap="var(--s2)" wrap="nowrap">
          <Button
            radius="xl"
            variant="subtle"
            color="gray"
            leftSection={<IconEraser size={16} />}
            onClick={() => setForgetting(true)}
          >
            Forget
          </Button>

          <Button
            radius="xl"
            color="chalk"
            leftSection={<IconSparkles size={16} />}
            loading={analyze.loading}
            onClick={async () => {
              const answered = await analyze.execute({ id: item.id })

              if (!answered) return

              say({ text: `Analyzing ${item.title ?? 'this item'}.` })
              refetch()
            }}
          >
            Analyze
          </Button>
        </Group>
      </Group>

      <Sure
        opened={forgetting}
        onClose={() => setForgetting(false)}
        title={`Forget ${item.title ?? 'this item'}?`}
        verb="Forget it"
        loading={forget.loading}
        onSure={async () => {
          const answered = await forget.execute({ id: item.id })

          if (!answered) return

          setForgetting(false)
          say({ text: `${item.title ?? 'That item'} is out of the catalog.` })
          navigate('/')
        }}
      >
        uris stops pointing at the{' '}
        <strong>
          {item.references.length}{' '}
          {item.references.length === 1 ? 'place' : 'places'}
        </strong>{' '}
        it lives and drops it from search. Not one of those places is touched —
        the files stay exactly where they are, and a later sync of the same
        resource will catalogue this again.
      </Sure>

      {viewable.length > 0 && (
        <Group align="flex-start" gap="var(--s4)">
          {viewable.map((reference) => (
            <a
              key={reference.id}
              href={reference.contentUrl}
              target="_blank"
              rel="noreferrer"
            >
              <Thumb
                url={reference.thumbnailUrl}
                kind={item.type}
                alt={reference.filename}
                size={230}
              />
            </a>
          ))}
        </Group>
      )}

      <Noting
        note={item.note ?? ''}
        busy={note.loading}
        onNote={async (next) => {
          const answered = await note.execute({ id: item.id, note: next })

          if (!answered) return false

          say({ text: next ? 'Noted.' : 'The note is gone.' })
          refetch()
          return true
        }}
      />

      {item.summary && (
        <Stack gap="var(--s2)">
          <div className="label">What uris made of it</div>
          <div className="panel" style={{ padding: 'var(--s4) var(--s5)' }}>
            <Text size="sm" style={{ lineHeight: 1.6, maxWidth: '72ch' }}>
              {item.summary}
            </Text>
          </div>
        </Stack>
      )}

      <Stack gap="var(--s3)">
        <div className="label">Where it lives</div>

        <div className="panel">
          {item.references.map((reference) => (
            <div
              key={reference.id}
              className="entry"
              data-spine="true"
              style={{ '--tone': 'var(--edge)' } as CSSProperties}
            >
              <div style={{ minWidth: 0 }}>
                <Group gap="var(--s2)">
                  <span className="entry-title">{reference.resource.key}</span>
                  <span className="tag" data-dot="false">
                    {reference.resource.type}
                  </span>
                </Group>

                <Text
                  size="xs"
                  mt="var(--s2)"
                  className="mono"
                  style={{ color: 'var(--soft)', wordBreak: 'break-all' }}
                >
                  {reference.locatorKey ?? '—'}
                </Text>

                <Text size="xs" c="dimmed" mt="var(--s1)">
                  {reference.contentType}
                  {reference.analyzedAt
                    ? ` · analyzed ${new Date(reference.analyzedAt).toLocaleString()}`
                    : ' · not analyzed'}
                </Text>
              </div>

              <Group gap="var(--s2)" wrap="nowrap">
                <Button
                  component="a"
                  href={reference.contentUrl}
                  target="_blank"
                  rel="noreferrer"
                  variant="default"
                  radius="xl"
                  size="xs"
                >
                  Open
                </Button>
                <Button
                  component="a"
                  href={`${reference.contentUrl}?download=1`}
                  variant="default"
                  radius="xl"
                  size="xs"
                >
                  Download
                </Button>
                {item.references.length > 1 && (
                  <Button
                    variant="subtle"
                    color="gray"
                    radius="xl"
                    size="xs"
                    leftSection={<IconCut size={14} />}
                    onClick={async () => {
                      const answered = await split.execute({ id: reference.id })

                      if (!answered) return

                      say({
                        text: `${reference.resource.key} is its own item now.`,
                      })
                      refetch()
                    }}
                  >
                    Split
                  </Button>
                )}
              </Group>
            </div>
          ))}
        </div>

        <div>
          <div className="eyebrow" style={{ marginBottom: 'var(--s3)' }}>
            Analysis
          </div>
          <RunTrail
            itemId={item.id}
            empty="This item has not been analyzed yet."
          />
        </div>
      </Stack>
    </Stack>
  )
}

function Naming({
  title,
  busy,
  onName,
}: {
  title: string
  busy: boolean
  onName: (next: string) => Promise<boolean>
}) {
  const [naming, setNaming] = useState(false)
  const [draft, setDraft] = useState(title)
  const box = useRef<HTMLInputElement | null>(null)

  useEffect(() => {
    if (naming) box.current?.select()
  }, [naming])

  const keep = async () => {
    if (draft.trim() === title.trim()) return setNaming(false)
    if (await onName(draft)) setNaming(false)
  }

  if (!naming) {
    return (
      <button
        type="button"
        className="naming"
        title="Rename"
        onClick={() => {
          setDraft(title)
          setNaming(true)
        }}
      >
        <h1 className="page-title">{title || 'Untitled'}</h1>
        <IconPencil size={17} stroke={1.7} />
      </button>
    )
  }

  return (
    <input
      ref={box}
      className="naming-box"
      value={draft}
      disabled={busy}
      aria-label="Name"
      onChange={(event) => setDraft(event.currentTarget.value)}
      onBlur={keep}
      onKeyDown={(event) => {
        if (event.key === 'Enter') keep()
        if (event.key === 'Escape') setNaming(false)
      }}
    />
  )
}

function Noting({
  note,
  busy,
  onNote,
}: {
  note: string
  busy: boolean
  onNote: (next: string) => Promise<boolean>
}) {
  const [writing, setWriting] = useState(false)
  const [draft, setDraft] = useState(note)

  useEffect(() => setDraft(note), [note])

  const keep = async () => {
    if (await onNote(draft.trim())) setWriting(false)
  }

  if (!writing) {
    return note ? (
      <Stack gap="var(--s2)">
        <Group justify="space-between" align="baseline">
          <div className="label">Your note</div>
          <Button
            size="compact-xs"
            variant="subtle"
            color="gray"
            onClick={() => setWriting(true)}
          >
            Edit
          </Button>
        </Group>

        <div className="panel note">{note}</div>
      </Stack>
    ) : (
      <Button
        w="fit-content"
        size="compact-sm"
        radius="xl"
        variant="subtle"
        color="gray"
        leftSection={<IconNote size={15} />}
        onClick={() => setWriting(true)}
      >
        Add a note
      </Button>
    )
  }

  return (
    <Stack gap="var(--s2)">
      <div className="label">Your note</div>

      <Textarea
        autosize
        autoFocus
        minRows={3}
        value={draft}
        disabled={busy}
        aria-label="Your note"
        placeholder="Anything you want to remember about this — uris will not touch it, and a search will find it."
        onChange={(event) => setDraft(event.currentTarget.value)}
        onKeyDown={(event) => {
          if (event.key === 'Escape') {
            setDraft(note)
            setWriting(false)
          }
        }}
      />

      <Group gap="var(--s2)">
        <Button
          size="xs"
          radius="xl"
          color="chalk"
          loading={busy}
          onClick={keep}
        >
          Keep it
        </Button>
        <Button
          size="xs"
          radius="xl"
          variant="default"
          onClick={() => {
            setDraft(note)
            setWriting(false)
          }}
        >
          Cancel
        </Button>
      </Group>
    </Stack>
  )
}
