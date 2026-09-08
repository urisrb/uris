import { Alert, Button, Group, Loader, Menu, Stack, Text } from '@mantine/core'
import {
  IconDots,
  IconFilePlus,
  IconFolderPlus,
  IconLayoutGrid,
  IconLayoutList,
  IconLink,
  IconPackageExport,
  IconPencil,
  IconPlayerPause,
  IconPlayerPlay,
  IconPlus,
  IconRefresh,
  IconTrash,
} from '@tabler/icons-react'
import {
  AnalysisProgressedDocument,
  CatalogDocument,
  DeleteFeedDocument,
  FeedAnalyzedDocument,
  FeedScheduleDocument,
  FeedsDocument,
  PauseFeedDocument,
  RunFeedDocument,
  SearchDocument,
  SetSettingDocument,
  SettingsDocument,
} from '@uris-to/client'
import { useQuery, useSubscription } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { usePages } from '../hooks/usePages'
import { useTitle } from '../hooks/useTitle'
import { tone } from '../kinds'
import { useAdd } from './Add'
import { Export } from './Export'
import { FeedForm } from './FeedForm'
import { KindBadge } from './KindBadge'
import { Lost } from './Lost'
import { useAloud, useSay } from './Say'
import { Sure } from './Sure'
import { Cover, Thumb } from './Thumb'
import { useUploads } from './Uploads'

const PAGE = 40

const VIEWS = ['list', 'cards'] as const

type View = (typeof VIEWS)[number]

const VIEW_SETTING = 'catalog_view'

const VIEW_ICONS = { list: IconLayoutList, cards: IconLayoutGrid }

const OPEN = new Set(['queued', 'running'])

function asView(value: string | null | undefined): View {
  return value === 'cards' ? 'cards' : 'list'
}

interface Row {
  id: string
  type: string
  title?: string | null
  summary?: string | null
  thumbnailUrl?: string | null
  analyzedAt?: string | null
}

interface Schedule {
  id: string
  prompt: string
  interval?: number | null
  pausedAt?: string | null
  turns?: number | null
}

interface Feed {
  id: string
  key: string
  title?: string | null
  connectedCount: number
  schedule?: Schedule | null
}

export function Catalog() {
  const { slug } = useParams()
  const [params] = useSearchParams()
  const kind = params.get('kind')
  const term = (params.get('q') ?? '').trim()

  const settings = useQuery(SettingsDocument)
  const feeds = useQuery(FeedsDocument, {})
  const save = useAloud(SetSettingDocument, 'That view could not be kept.')
  const [picked, setPicked] = useState<View | null>(null)

  const stored = settings.data?.settings.find(
    (setting) => setting.key === VIEW_SETTING,
  )?.value
  const view = asView(picked ?? stored)

  const pick = (next: View) => {
    setPicked(next)
    save.execute({ key: VIEW_SETTING, value: next })
  }

  const known = (feeds.data?.feeds ?? []) as Feed[]
  const here = slug ? (known.find((feed) => feed.key === slug) ?? null) : null

  if (slug && !feeds.data) return <Loader size="sm" color="var(--brass)" />
  if (slug && !here) return <Lost />

  return (
    <Listing
      key={`${slug ?? ''} ${kind ?? ''} ${term}`}
      kind={kind}
      term={term}
      feed={here}
      feeds={known}
      view={view}
      onPick={pick}
      onChanged={feeds.refetch}
    />
  )
}

function Listing({
  kind,
  term,
  feed,
  feeds,
  view,
  onPick,
  onChanged,
}: {
  kind: string | null
  term: string
  feed: Feed | null
  feeds: Feed[]
  view: View
  onPick: (next: View) => void
  onChanged: () => void
}) {
  const searching = term.length > 0

  const [cursor, setCursor] = useState<string | null>(null)
  const { settledAt } = useUploads()
  const { addedAt } = useAdd()

  const catalog = useQuery(
    CatalogDocument,
    { type: kind, connectedTo: feed?.id ?? null, after: cursor, limit: PAGE },
    { skip: searching },
  )
  const found = useQuery(
    SearchDocument,
    { query: term, type: kind, after: cursor, limit: PAGE },
    { skip: !searching },
  )
  const { data: analyzed } = useSubscription(FeedAnalyzedDocument)
  const { data: progressed } = useSubscription(AnalysisProgressedDocument, {})

  const thinking = useQuery(
    FeedScheduleDocument,
    { key: feed?.key ?? '' },
    { skip: !feed },
  )

  const page = searching ? found.data?.search : catalog.data?.feeds
  const [rows] = usePages<Row>(page, cursor)

  const analyses = thinking.data?.feed?.analyses ?? []
  const open = analyses.find((analysis) => OPEN.has(analysis.status))

  const streamed = progressed?.analysisProgressed.analysis
  const settled =
    streamed &&
    !OPEN.has(streamed.status) &&
    analyses.some((analysis) => analysis.id === streamed.id)

  useTitle(
    feed ? `/${feed.key}` : term ? `${term} — search` : kind ? kind : null,
  )

  useEffect(() => {
    if (analyzed && !searching) catalog.refetch()
  }, [analyzed, searching, catalog.refetch])

  useEffect(() => {
    if ((settledAt || addedAt) && !searching) {
      setCursor(null)
      catalog.refetch()
    }
  }, [settledAt, addedAt, searching, catalog.refetch])

  useEffect(() => {
    if (!settled) return

    setCursor(null)
    catalog.refetch()
    thinking.refetch()
  }, [settled, catalog.refetch, thinking.refetch])

  const total = searching ? (found.data?.search.total ?? null) : null
  const loading = searching ? found.loading : catalog.loading
  const error = searching ? found.error : catalog.error

  return (
    <Stack gap="var(--s5)">
      <div className="page-head">
        <div className="eyebrow">
          {searching ? (
            <>
              <span className="figure">{rows.length.toLocaleString()}</span>
              {total !== null && total > rows.length && (
                <>
                  {' of '}
                  <span className="figure">{total.toLocaleString()}</span>
                </>
              )}{' '}
              {total === 1 ? 'match' : 'matches'}
              {kind ? ` of kind ${kind}` : ''}
            </>
          ) : (
            <>
              <span className="figure">{rows.length.toLocaleString()}</span>{' '}
              {kind ? kind : 'items'}
              {page?.hasMore ? ' so far' : ''}
              {feed ? ' kept by this feed' : ''}
            </>
          )}
        </div>

        <Group gap="var(--s2)" wrap="nowrap">
          <Kinds />
          <Switcher view={view} onPick={onPick} />
          <Tools kind={kind} term={term} />
        </Group>
      </div>

      <Shelf
        feeds={feeds}
        here={feed}
        running={Boolean(open)}
        onChanged={() => {
          onChanged()
          thinking.refetch()
        }}
      />

      {feed?.schedule && (
        <div className="prompt-line">{feed.schedule.prompt}</div>
      )}

      {open && (
        <Thinking
          key={open.id}
          id={open.id}
          cap={thinking.data?.feed?.schedule?.turns}
        />
      )}

      {error && <Alert color="red">{error.message}</Alert>}

      {rows.length > 0 && <Rows rows={rows} view={view} />}

      {loading && rows.length === 0 && (
        <Loader size="sm" color="var(--brass)" />
      )}

      {!loading && rows.length === 0 && (
        <Empty searching={searching} kind={kind} feed={feed} />
      )}

      {page?.hasMore && (
        <Group justify="center">
          <Button
            variant="default"
            radius="xl"
            onClick={() => setCursor(page.nextCursor ?? null)}
            loading={loading}
          >
            Load more
          </Button>
        </Group>
      )}
    </Stack>
  )
}

// A feed is a saved way of cutting the catalog, so it sits with the catalog
// rather than in a section of its own.
function Shelf({
  feeds,
  here,
  running,
  onChanged,
}: {
  feeds: Feed[]
  here: Feed | null
  running?: boolean
  onChanged: () => void
}) {
  const say = useSay()
  const navigate = useNavigate()
  const [making, setMaking] = useState(false)
  const [editing, setEditing] = useState(false)
  const [deleting, setDeleting] = useState(false)

  const start = useAloud(RunFeedDocument, 'That feed could not be run.')
  const pause = useAloud(PauseFeedDocument, 'That feed could not be paused.')
  const remove = useAloud(DeleteFeedDocument, 'That feed could not be deleted.')

  return (
    <div className="shelf">
      <Link
        to="/"
        className="chip"
        data-on={here === null}
        aria-current={here === null ? 'page' : undefined}
      >
        Everything
      </Link>

      {feeds.map((feed) => (
        <Link
          key={feed.id}
          to={`/${feed.key}`}
          className="chip"
          data-on={feed.id === here?.id}
          aria-current={feed.id === here?.id ? 'page' : undefined}
        >
          /{feed.key}
          {feed.schedule?.pausedAt ? (
            <span className="chip-note">paused</span>
          ) : null}
        </Link>
      ))}

      <button
        type="button"
        className="chip chip-new"
        aria-label="New feed"
        onClick={() => setMaking(true)}
      >
        <IconPlus size={14} stroke={2} />
      </button>

      {here && (
        <Menu position="bottom-start" width={200}>
          <Menu.Target>
            <button type="button" className="chip" aria-label={`/${here.key}`}>
              <IconDots size={14} stroke={1.8} />
            </button>
          </Menu.Target>
          <Menu.Dropdown>
            <Menu.Item
              leftSection={<IconRefresh size={15} stroke={1.6} />}
              disabled={running || start.loading}
              onClick={async () => {
                const answered = await start.execute({ id: here.id })

                if (!answered) return

                say({ text: `/${here.key} is running.` })
                onChanged()
              }}
            >
              {running ? 'Running' : 'Run now'}
            </Menu.Item>

            <Menu.Item
              leftSection={<IconPencil size={15} stroke={1.6} />}
              onClick={() => setEditing(true)}
            >
              Edit
            </Menu.Item>

            {here.schedule?.interval ? (
              <Menu.Item
                leftSection={
                  here.schedule?.pausedAt ? (
                    <IconPlayerPlay size={15} stroke={1.6} />
                  ) : (
                    <IconPlayerPause size={15} stroke={1.6} />
                  )
                }
                onClick={async () => {
                  const answered = await pause.execute({
                    id: here.id,
                    paused: !here.schedule?.pausedAt,
                  })

                  if (!answered) return

                  say({
                    text: here.schedule?.pausedAt
                      ? `/${here.key} runs on its own again.`
                      : `/${here.key} is paused. It will only run by hand.`,
                  })
                  onChanged()
                }}
              >
                {here.schedule?.pausedAt ? 'Resume' : 'Pause'}
              </Menu.Item>
            ) : null}

            <Menu.Divider />

            <Menu.Item
              color="red"
              leftSection={<IconTrash size={15} stroke={1.6} />}
              onClick={() => setDeleting(true)}
            >
              Delete
            </Menu.Item>
          </Menu.Dropdown>
        </Menu>
      )}

      <FeedForm
        opened={making || editing}
        onClose={() => {
          setMaking(false)
          setEditing(false)
        }}
        feed={editing ? here : undefined}
        onSaved={(saved) => {
          say({ text: `/${saved} is saved.` })
          onChanged()
          navigate(`/${saved}`)
        }}
      />

      {here && (
        <Sure
          opened={deleting}
          onClose={() => setDeleting(false)}
          title={`Delete /${here.key}?`}
          verb="Delete it"
          loading={remove.loading}
          onSure={async () => {
            const answered = await remove.execute({ id: here.id })

            if (!answered) return

            const kept = answered.deleteFeed?.kept ?? 0

            setDeleting(false)
            say({
              text: kept
                ? `/${here.key} is gone. The ${kept} ${kept === 1 ? 'item' : 'items'} it wrote stayed in your catalog.`
                : `/${here.key} is gone.`,
            })
            onChanged()
            navigate('/')
          }}
        >
          The prompt and its run history go. Anything it wrote stays in your
          catalog as an ordinary item — deleting the feed that found something
          is not the same as throwing the something away.
        </Sure>
      )}
    </div>
  )
}

function Thinking({ id, cap }: { id: string; cap?: number | null }) {
  const [turns, setTurns] = useState<
    { turn: number; calls: string[]; said?: string | null }[]
  >([])
  const { data } = useSubscription(AnalysisProgressedDocument, { id })

  useEffect(() => {
    const streamed = data?.analysisProgressed.analysis.turns

    if (!Array.isArray(streamed)) return

    setTurns(
      streamed as { turn: number; calls: string[]; said?: string | null }[],
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

function Rows({ rows, view }: { rows: Row[]; view: View }) {
  if (view === 'cards') {
    return (
      <div className="grid">
        {rows.map((item) => (
          <Link key={item.id} to={`/items/${item.id}`} className="card">
            <Cover
              url={item.thumbnailUrl}
              kind={item.type}
              alt={item.title ?? ''}
            />
            <div className="card-body">
              <div className="card-title">{item.title ?? 'Untitled'}</div>
              {item.summary ? (
                <div className="card-summary">{item.summary}</div>
              ) : (
                !item.analyzedAt && (
                  <div className="card-summary">Not analyzed yet</div>
                )
              )}
              <div className="card-foot">
                <KindBadge kind={item.type} />
              </div>
            </div>
          </Link>
        ))}
      </div>
    )
  }

  return (
    <div className="panel">
      {rows.map((item) => (
        <Link key={item.id} to={`/items/${item.id}`} className="entry">
          <Thumb
            url={item.thumbnailUrl}
            kind={item.type}
            alt={item.title ?? ''}
            size={48}
          />
          <div style={{ minWidth: 0 }}>
            <div className="entry-title">{item.title ?? 'Untitled'}</div>
            {item.summary ? (
              <div className="entry-summary">{item.summary}</div>
            ) : (
              !item.analyzedAt && (
                <div className="entry-summary">Not analyzed yet</div>
              )
            )}
          </div>
          <KindBadge kind={item.type} />
        </Link>
      ))}
    </div>
  )
}

function Kinds() {
  const [params] = useSearchParams()
  const { settledAt } = useUploads()
  const { addedAt } = useAdd()
  const { data, refetch } = useQuery(CatalogDocument, {
    kind: null,
    after: null,
    limit: 1,
  })

  useEffect(() => {
    if (settledAt || addedAt) refetch()
  }, [settledAt, addedAt, refetch])

  const kind = params.get('kind')
  const kinds = data?.types ?? []
  const total = kinds.reduce((sum, entry) => sum + entry.count, 0)

  const linkTo = (next: string | null) => {
    const held = new URLSearchParams(params)

    if (next) held.set('kind', next)
    else held.delete('kind')

    const query = held.toString()

    return query ? `/?${query}` : '/'
  }

  return (
    <Menu position="bottom-end" width={230}>
      <Menu.Target>
        <Button
          variant={kind ? 'light' : 'default'}
          color="gray"
          size="compact-sm"
          radius="xl"
          leftSection={
            kind ? (
              <span
                className="dot"
                style={{ '--tone': tone(kind) } as CSSProperties}
              />
            ) : undefined
          }
        >
          {kind ?? 'All kinds'}
        </Button>
      </Menu.Target>
      <Menu.Dropdown>
        <Menu.Item component={Link} to={linkTo(null)}>
          <Group justify="space-between" gap="var(--s4)">
            <span>everything</span>
            <span className="figure">{total.toLocaleString()}</span>
          </Group>
        </Menu.Item>

        {kinds.length > 0 && <Menu.Divider />}

        {kinds.map((entry) => (
          <Menu.Item
            key={entry.type}
            component={Link}
            to={linkTo(entry.type === kind ? null : entry.type)}
            leftSection={
              <span
                className="dot"
                style={{ '--tone': tone(entry.type) } as CSSProperties}
              />
            }
          >
            <Group justify="space-between" gap="var(--s4)">
              <span>{entry.type}</span>
              <span className="figure">{entry.count.toLocaleString()}</span>
            </Group>
          </Menu.Item>
        ))}
      </Menu.Dropdown>
    </Menu>
  )
}

function Tools({ kind, term }: { kind: string | null; term: string }) {
  const [exporting, setExporting] = useState(false)

  return (
    <>
      <Export
        opened={exporting}
        onClose={() => setExporting(false)}
        type={kind}
        term={term}
      />

      <Menu position="bottom-end" width={210}>
        <Menu.Target>
          <Button
            variant="subtle"
            color="gray"
            size="compact-sm"
            radius="xl"
            aria-label="More"
          >
            <IconDots size={16} stroke={1.8} />
          </Button>
        </Menu.Target>
        <Menu.Dropdown>
          <Menu.Item
            leftSection={<IconPackageExport size={16} stroke={1.6} />}
            onClick={() => setExporting(true)}
          >
            Export these…
          </Menu.Item>
        </Menu.Dropdown>
      </Menu>
    </>
  )
}

function Switcher({
  view,
  onPick,
}: {
  view: View
  onPick: (next: View) => void
}) {
  return (
    <div className="switcher">
      {VIEWS.map((value) => {
        const Icon = VIEW_ICONS[value]

        return (
          <button
            key={value}
            type="button"
            data-on={view === value}
            aria-pressed={view === value}
            aria-label={value === 'cards' ? 'Cards' : 'List'}
            onClick={() => onPick(value)}
          >
            <Icon size={16} stroke={1.7} />
          </button>
        )
      })}
    </div>
  )
}

function Empty({
  searching,
  kind,
  feed,
}: {
  searching: boolean
  kind: string | null
  feed: Feed | null
}) {
  const { add } = useUploads()
  const { open } = useAdd()
  const picker = useRef<HTMLInputElement>(null)
  const folders = useRef<HTMLInputElement>(null)

  if (searching) {
    return (
      <Text c="dimmed" size="sm">
        Nothing matches that yet. An item turns up here once it has been
        analyzed or you have written a note on it, so anything still waiting on
        both will not.
      </Text>
    )
  }

  if (feed) {
    return (
      <div className="panel" style={{ padding: 'var(--s6)' }}>
        <Text c="dimmed" size="sm">
          Nothing kept yet. Run it and it will search your catalog for what the
          sentence above describes.
        </Text>
      </div>
    )
  }

  return (
    <div
      className="panel"
      style={{ padding: 'var(--s7) var(--s6)', textAlign: 'center' }}
    >
      <div
        style={{
          fontSize: 'var(--t-title)',
          fontWeight: 600,
          letterSpacing: '-0.02em',
          color: 'var(--soft)',
        }}
      >
        {kind ? `Nothing of kind ${kind} yet` : 'Nothing indexed yet'}
      </div>
      <Text c="dimmed" size="sm" mt="var(--s3)" mx="auto" maw="46ch">
        Drop a file or a whole folder anywhere on this page, paste an address or
        a screenshot, or sync a resource and it will fill up on its own.
      </Text>

      <input
        ref={picker}
        type="file"
        multiple
        hidden
        onChange={(event) => {
          if (event.currentTarget.files) add(event.currentTarget.files)
          event.currentTarget.value = ''
        }}
      />

      <input
        ref={folders}
        type="file"
        multiple
        hidden
        {...{ webkitdirectory: '' }}
        onChange={(event) => {
          if (event.currentTarget.files) add(event.currentTarget.files)
          event.currentTarget.value = ''
        }}
      />

      <Group justify="center" gap="var(--s3)" mt="var(--s5)">
        <Button
          radius="xl"
          color="chalk"
          leftSection={<IconFilePlus size={16} />}
          onClick={() => picker.current?.click()}
        >
          Choose files
        </Button>
        <Button
          radius="xl"
          variant="default"
          leftSection={<IconFolderPlus size={16} />}
          onClick={() => folders.current?.click()}
        >
          Choose a folder
        </Button>
        <Button
          radius="xl"
          variant="default"
          leftSection={<IconLink size={16} />}
          onClick={() => open()}
        >
          Add a link or a note
        </Button>
      </Group>
    </div>
  )
}
