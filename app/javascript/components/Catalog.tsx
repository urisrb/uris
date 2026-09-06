import { Alert, Button, Group, Loader, Stack, Text } from '@mantine/core'
import {
  IconFilePlus,
  IconFolderPlus,
  IconLayoutGrid,
  IconLayoutList,
  IconLink,
} from '@tabler/icons-react'
import {
  CatalogDocument,
  ItemAnalyzedDocument,
  SearchDocument,
  SetSettingDocument,
  SettingsDocument,
} from '@uris-to/client'
import { useMutation, useQuery, useSubscription } from '@uris-to/client/react'
import { useEffect, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useAdd } from './Add'
import { KindBadge } from './KindBadge'
import { Cover, Thumb } from './Thumb'
import { useUploads } from './Uploads'

const PAGE = 40

const VIEWS = ['list', 'cards'] as const

type View = (typeof VIEWS)[number]

const VIEW_SETTING = 'catalog_view'

const VIEW_ICONS = { list: IconLayoutList, cards: IconLayoutGrid }

function asView(value: string | null | undefined): View {
  return value === 'cards' ? 'cards' : 'list'
}

interface Row {
  id: string
  kind: string
  title?: string | null
  summary?: string | null
  thumbnailUrl?: string | null
  analyzedAt?: string | null
}

export function Catalog() {
  const [params] = useSearchParams()
  const kind = params.get('kind')
  const term = (params.get('q') ?? '').trim()

  const settings = useQuery(SettingsDocument)
  const save = useMutation(SetSettingDocument)
  const [picked, setPicked] = useState<View | null>(null)

  const stored = settings.data?.settings.find(
    (setting) => setting.key === VIEW_SETTING,
  )?.value

  const pick = (next: View) => {
    setPicked(next)
    save.execute({ key: VIEW_SETTING, value: next })
  }

  return (
    <Listing
      key={`${kind ?? ''} ${term}`}
      kind={kind}
      term={term}
      view={asView(picked ?? stored)}
      onPick={pick}
    />
  )
}

function Listing({
  kind,
  term,
  view,
  onPick,
}: {
  kind: string | null
  term: string
  view: View
  onPick: (next: View) => void
}) {
  const searching = term.length > 0

  const [cursor, setCursor] = useState<string | null>(null)
  const [pages, setPages] = useState<Row[]>([])
  const { settledAt } = useUploads()
  const { addedAt } = useAdd()

  const catalog = useQuery(
    CatalogDocument,
    { kind, after: cursor, limit: PAGE },
    { skip: searching },
  )
  const found = useQuery(
    SearchDocument,
    { query: term, kind },
    { skip: !searching },
  )
  const { data: analyzed } = useSubscription(ItemAnalyzedDocument)

  useEffect(() => {
    const page = catalog.data?.items
    if (!page) return

    setPages((existing) =>
      cursor ? [...existing, ...page.nodes] : [...page.nodes],
    )
  }, [catalog.data, cursor])

  useEffect(() => {
    if (analyzed && !searching) catalog.refetch()
  }, [analyzed, searching, catalog.refetch])

  useEffect(() => {
    if ((settledAt || addedAt) && !searching) {
      setCursor(null)
      catalog.refetch()
    }
  }, [settledAt, addedAt, searching, catalog.refetch])

  const rows: Row[] = searching ? (found.data?.search ?? []) : pages
  const page = catalog.data?.items
  const loading = searching ? found.loading : catalog.loading
  const error = searching ? found.error : catalog.error

  return (
    <Stack gap="var(--s5)">
      <div className="page-head">
        <div>
          <h1 className="page-title">
            {searching ? term : (catalog.data?.tenant?.name ?? 'Catalog')}
          </h1>
          <div className="eyebrow" style={{ marginTop: 'var(--s2)' }}>
            {searching ? (
              <>
                <span className="figure">{rows.length.toLocaleString()}</span>{' '}
                {rows.length === 1 ? 'match' : 'matches'}
                {kind ? ` of kind ${kind}` : ''}
              </>
            ) : (
              <>
                <span className="figure">{rows.length.toLocaleString()}</span>{' '}
                {kind ? kind : 'items'}
                {page?.hasMore ? ' so far' : ''}
              </>
            )}
          </div>
        </div>

        <Switcher view={view} onPick={onPick} />
      </div>

      {error && <Alert color="red">{error.message}</Alert>}

      {rows.length > 0 &&
        (view === 'cards' ? (
          <div className="grid">
            {rows.map((item) => (
              <Link key={item.id} to={`/items/${item.id}`} className="card">
                <Cover
                  url={item.thumbnailUrl}
                  kind={item.kind}
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
                    <KindBadge kind={item.kind} />
                  </div>
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <div className="panel">
            {rows.map((item) => (
              <Link key={item.id} to={`/items/${item.id}`} className="entry">
                <Thumb
                  url={item.thumbnailUrl}
                  kind={item.kind}
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
                <KindBadge kind={item.kind} />
              </Link>
            ))}
          </div>
        ))}

      {loading && rows.length === 0 && (
        <Loader size="sm" color="var(--brass)" />
      )}

      {!loading && rows.length === 0 && (
        <Empty searching={searching} kind={kind} />
      )}

      {!searching && page?.hasMore && (
        <Group justify="center">
          <Button
            variant="default"
            radius="xl"
            onClick={() => setCursor(page.nextCursor ?? null)}
            loading={catalog.loading}
          >
            Load more
          </Button>
        </Group>
      )}
    </Stack>
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
}: {
  searching: boolean
  kind: string | null
}) {
  const { add } = useUploads()
  const { open } = useAdd()
  const picker = useRef<HTMLInputElement>(null)
  const folders = useRef<HTMLInputElement>(null)

  if (searching) {
    return (
      <Text c="dimmed" size="sm">
        Nothing matches that yet. Analysis is what makes an item searchable, so
        anything still waiting on it will not turn up here.
      </Text>
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
