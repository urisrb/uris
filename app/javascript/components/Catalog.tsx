import {
  Alert,
  Box,
  Button,
  Center,
  Chip,
  Group,
  Loader,
  Paper,
  Stack,
  Text,
  TextInput,
  Title,
} from '@mantine/core'
import { IconSearch } from '@tabler/icons-react'
import {
  CatalogDocument,
  SearchDocument,
  ThingAnalyzedDocument,
} from '@things/client'
import { useQuery, useSubscription } from '@things/client/react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { KindBadge } from './KindBadge'
import { Thumb } from './Thumb'

const PAGE = 40

interface Row {
  id: string
  kind: string
  title?: string | null
  summary?: string | null
  thumbnailUrl?: string | null
  analyzedAt?: string | null
}

export function Catalog() {
  const [kind, setKind] = useState<string | null>(null)
  const [query, setQuery] = useState('')
  const [term, setTerm] = useState('')
  const [cursor, setCursor] = useState<string | null>(null)
  const [pages, setPages] = useState<Row[]>([])

  const searching = term.trim().length > 0

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
  const { data: analyzed } = useSubscription(ThingAnalyzedDocument)

  useEffect(() => {
    const page = catalog.data?.things
    if (!page) return

    setPages((existing) =>
      cursor ? [...existing, ...page.nodes] : [...page.nodes],
    )
  }, [catalog.data, cursor])

  useEffect(() => {
    if (analyzed && !searching) catalog.refetch()
  }, [analyzed, searching, catalog.refetch])

  const reset = (nextKind: string | null) => {
    setKind(nextKind)
    setCursor(null)
    setPages([])
  }

  const rows: Row[] = searching ? (found.data?.search ?? []) : pages
  const page = catalog.data?.things
  const loading = searching ? found.loading : catalog.loading
  const error = searching ? found.error : catalog.error

  return (
    <Stack gap="lg">
      <Group justify="space-between" align="flex-end">
        <Box>
          <Title order={2}>{catalog.data?.tenant?.name ?? 'Catalog'}</Title>
          <Text c="dimmed" size="sm">
            {searching
              ? `${rows.length} matching "${term}"`
              : `${rows.length} things${page?.hasMore ? ' so far' : ''}`}
          </Text>
        </Box>

        <form
          onSubmit={(event) => {
            event.preventDefault()
            setTerm(query)
          }}
        >
          <Group gap="xs">
            <TextInput
              value={query}
              onChange={(event) => setQuery(event.currentTarget.value)}
              placeholder="Search everything"
              leftSection={<IconSearch size={16} />}
              w={280}
            />
            <Button type="submit" variant="default">
              Search
            </Button>
            {searching && (
              <Button
                variant="subtle"
                onClick={() => {
                  setQuery('')
                  setTerm('')
                }}
              >
                Clear
              </Button>
            )}
          </Group>
        </form>
      </Group>

      <Group gap="xs">
        <Chip checked={kind === null} onClick={() => reset(null)} size="sm">
          everything
        </Chip>
        {catalog.data?.kinds.map((entry) => (
          <Chip
            key={entry.kind}
            checked={kind === entry.kind}
            onClick={() => reset(kind === entry.kind ? null : entry.kind)}
            size="sm"
          >
            {entry.kind} · {entry.count}
          </Chip>
        ))}
      </Group>

      {error && <Alert color="red">{error.message}</Alert>}

      <Stack gap="xs">
        {rows.map((thing) => (
          <Paper
            key={thing.id}
            component={Link}
            to={`/things/${thing.id}`}
            withBorder
            p="sm"
            style={{
              textDecoration: 'none',
              color: 'inherit',
              display: 'block',
            }}
          >
            <Group align="flex-start" wrap="nowrap">
              <Thumb
                url={thing.thumbnailUrl}
                alt={thing.title ?? ''}
                size={56}
              />
              <Box style={{ minWidth: 0, flex: 1 }}>
                <Group gap="xs" wrap="nowrap">
                  <Text fw={500} truncate>
                    {thing.title ?? 'Untitled'}
                  </Text>
                  <KindBadge kind={thing.kind} />
                  {!thing.analyzedAt && (
                    <Text size="xs" c="dimmed">
                      not analyzed
                    </Text>
                  )}
                </Group>
                {thing.summary && (
                  <Text size="sm" c="dimmed" lineClamp={2}>
                    {thing.summary}
                  </Text>
                )}
              </Box>
            </Group>
          </Paper>
        ))}
      </Stack>

      {loading && (
        <Center py="md">
          <Loader size="sm" />
        </Center>
      )}

      {!loading && rows.length === 0 && (
        <Text c="dimmed">
          Nothing here yet. Sync a resource and it will fill up.
        </Text>
      )}

      {!searching && page?.hasMore && (
        <Center>
          <Button
            variant="default"
            onClick={() => setCursor(page.nextCursor ?? null)}
          >
            Load more
          </Button>
        </Center>
      )}
    </Stack>
  )
}
