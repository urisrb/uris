import {
  Button,
  Group,
  Modal,
  Select,
  Stack,
  Text,
  TextInput,
} from '@mantine/core'
import { IconPackageExport } from '@tabler/icons-react'
import {
  CatalogDocument,
  ExportItemsDocument,
  ResourcesDocument,
} from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { useEffect, useState } from 'react'
import { useAloud, useSay } from './Say'

interface Props {
  opened: boolean
  onClose: () => void
  kind: string | null
  term: string
}

export function Export({ opened, onClose, kind, term }: Props) {
  const say = useSay()
  const resources = useQuery(ResourcesDocument, undefined, { skip: !opened })
  const catalog = useQuery(
    CatalogDocument,
    { kind: null, after: null, limit: 1 },
    { skip: !opened },
  )
  const start = useAloud(ExportItemsDocument, 'That export could not start.')

  const [destination, setDestination] = useState<string | null>(null)
  const [narrowed, setNarrowed] = useState<string | null>(null)
  const [query, setQuery] = useState('')

  useEffect(() => {
    if (!opened) return

    setDestination(null)
    setNarrowed(kind)
    setQuery(term)
  }, [opened, kind, term])

  const storage = (resources.data?.resources ?? []).filter((resource) =>
    resource.capabilities.includes('storage'),
  )
  const fallback = storage.find((resource) => resource.defaultStorage)
  const kinds = catalog.data?.kinds ?? []

  const send = async () => {
    const answered = await start.execute({
      destinationId: destination,
      kind: narrowed,
      query: query.trim() || null,
    })

    if (!answered) return

    onClose()
    say({ text: 'The export is running. Watch it under Runs.' })
  }

  return (
    <Modal opened={opened} onClose={onClose} title="Export items">
      <Stack gap="var(--s4)">
        <Text size="sm" c="dimmed">
          Writes a copy of everything that matches into a resource you can reach
          from outside uris. It runs in the background and shows up under Runs.
        </Text>

        <Select
          label="Write them to"
          description={
            fallback
              ? `Left alone, they land in ${fallback.key}.`
              : 'This tenant has no default storage, so pick one.'
          }
          placeholder={fallback ? fallback.key : 'Pick a storage resource'}
          value={destination}
          onChange={setDestination}
          clearable
          data={storage.map((resource) => ({
            value: resource.id,
            label: `${resource.key} · ${resource.type}`,
          }))}
        />

        <Select
          label="Of kind"
          placeholder="every kind"
          value={narrowed}
          onChange={setNarrowed}
          clearable
          data={kinds.map((entry) => ({
            value: entry.kind,
            label: `${entry.kind} (${entry.count.toLocaleString()})`,
          }))}
        />

        <TextInput
          label="Matching"
          description="Left empty, everything of that kind goes."
          placeholder="a search, the way you would type it in the bar"
          value={query}
          onChange={(event) => setQuery(event.currentTarget.value)}
        />

        <Group justify="flex-end" gap="var(--s2)">
          <Button variant="default" onClick={onClose}>
            Cancel
          </Button>
          <Button
            color="chalk"
            loading={start.loading}
            disabled={!destination && !fallback}
            leftSection={<IconPackageExport size={16} />}
            onClick={send}
          >
            Export
          </Button>
        </Group>
      </Stack>
    </Modal>
  )
}
