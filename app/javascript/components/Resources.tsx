import {
  Alert,
  Button,
  Group,
  Loader,
  NumberInput,
  Stack,
  Text,
  Tooltip,
} from '@mantine/core'
import {
  IconCheck,
  IconPlus,
  IconRefresh,
  IconStar,
  IconStarFilled,
} from '@tabler/icons-react'
import {
  CheckResourceDocument,
  ResourcesDocument,
  SetDefaultStorageDocument,
  SetSyncIntervalDocument,
  SyncResourceDocument,
} from '@uris-to/client'
import { useMutation, useQuery } from '@uris-to/client/react'
import { type CSSProperties, useState } from 'react'
import { Attach } from './Attach'

interface Resource {
  id: string
  type: string
  key: string
  name?: string | null
  healthy: boolean
  checkedAt?: string | null
  checkError?: string | null
  syncing: boolean
  defaultStorage: boolean
  itemsCount: number
  capabilities: string[]
  syncInterval?: number | null
  syncedAt?: string | null
  nextSyncAt?: string | null
}

function toneFor(resource: Resource) {
  if (resource.syncing) return 'var(--busy)'
  if (!resource.checkedAt) return 'var(--edge)'

  return resource.healthy ? 'var(--ok)' : 'var(--bad)'
}

function standing(resource: Resource) {
  if (resource.syncing) return 'syncing'
  if (!resource.checkedAt) return 'never checked'

  return resource.healthy ? 'reachable' : 'failing'
}

function schedule(resource: Resource) {
  if (!resource.syncInterval) return 'on demand only'

  const every = `every ${Math.round(resource.syncInterval / 60)} min`
  const next = resource.nextSyncAt
    ? new Date(resource.nextSyncAt).toLocaleTimeString()
    : '—'

  return `${every} · next ${next}`
}

export function Resources() {
  const { data, loading, error, refetch } = useQuery(ResourcesDocument)
  const sync = useMutation(SyncResourceDocument)
  const check = useMutation(CheckResourceDocument)
  const setDefault = useMutation(SetDefaultStorageDocument)
  const setInterval = useMutation(SetSyncIntervalDocument)
  const [minutes, setMinutes] = useState<Record<string, number | string>>({})
  const [attaching, setAttaching] = useState(false)

  if (loading && !data) return <Loader size="sm" color="var(--brass)" />
  if (error) return <Alert color="red">{error.message}</Alert>

  const resources = (data?.resources ?? []) as Resource[]

  return (
    <Stack gap="var(--s5)">
      <Group justify="space-between" align="flex-end">
        <div>
          <h1 className="page-title">Resources</h1>
          <div className="eyebrow" style={{ marginTop: 'var(--s2)' }}>
            The places your items live, and what each one can be asked to do
          </div>
        </div>
        <Button
          leftSection={<IconPlus size={16} stroke={2} />}
          onClick={() => setAttaching(true)}
        >
          Attach one
        </Button>
      </Group>

      <Attach
        opened={attaching}
        onClose={() => setAttaching(false)}
        onAttached={refetch}
      />

      <div className="panel">
        {resources.map((resource) => (
          <div
            key={resource.id}
            className="entry"
            data-spine="true"
            style={{ '--tone': toneFor(resource) } as CSSProperties}
          >
            <div style={{ minWidth: 0 }}>
              <Group gap="var(--s2)" wrap="wrap">
                <span className="entry-title">{resource.key}</span>
                <span className="tag" data-dot="false">
                  {resource.type}
                </span>
                <Tooltip
                  label={
                    resource.checkError ??
                    (resource.checkedAt
                      ? `checked ${new Date(resource.checkedAt).toLocaleString()}`
                      : 'not checked yet')
                  }
                >
                  <span
                    className="tag"
                    style={{ '--tone': toneFor(resource) } as CSSProperties}
                  >
                    {standing(resource)}
                  </span>
                </Tooltip>
                {resource.defaultStorage && (
                  <span
                    className="tag"
                    style={{ '--tone': 'var(--brass)' } as CSSProperties}
                  >
                    drops land here
                  </span>
                )}
              </Group>

              <Text size="sm" c="dimmed" mt="var(--s2)">
                {resource.name ?? '—'} ·{' '}
                <span className="figure">
                  {resource.itemsCount.toLocaleString()}
                </span>{' '}
                items · {resource.capabilities.join(', ')}
              </Text>

              <Text size="xs" c="dimmed" mt="var(--s1)">
                {schedule(resource)}
                {resource.syncedAt &&
                  ` · last ${new Date(resource.syncedAt).toLocaleString()}`}
              </Text>

              {resource.checkError && (
                <Text size="xs" mt="var(--s2)" style={{ color: 'var(--bad)' }}>
                  {resource.checkError}
                </Text>
              )}
            </div>

            <Stack gap="var(--s2)" align="flex-end">
              <Group gap="var(--s2)" wrap="nowrap">
                <Button
                  size="xs"
                  radius="xl"
                  variant="default"
                  leftSection={<IconCheck size={14} />}
                  onClick={async () => {
                    await check.execute({ id: resource.id })
                    refetch()
                  }}
                >
                  Check
                </Button>
                <Button
                  size="xs"
                  radius="xl"
                  color="chalk"
                  leftSection={<IconRefresh size={14} />}
                  disabled={resource.syncing}
                  onClick={async () => {
                    await sync.execute({ id: resource.id })
                    refetch()
                  }}
                >
                  Sync
                </Button>
                {resource.capabilities.includes('storage') && (
                  <Button
                    size="xs"
                    radius="xl"
                    variant="subtle"
                    color="gray"
                    disabled={resource.defaultStorage}
                    leftSection={
                      resource.defaultStorage ? (
                        <IconStarFilled size={14} />
                      ) : (
                        <IconStar size={14} />
                      )
                    }
                    onClick={async () => {
                      await setDefault.execute({ id: resource.id })
                      refetch()
                    }}
                  >
                    Take drops
                  </Button>
                )}
              </Group>

              <Group gap="var(--s2)" wrap="nowrap">
                <NumberInput
                  size="xs"
                  w={110}
                  min={1}
                  radius="xl"
                  placeholder="minutes"
                  value={
                    minutes[resource.id] ??
                    (resource.syncInterval ? resource.syncInterval / 60 : '')
                  }
                  onChange={(value) =>
                    setMinutes((current) => ({
                      ...current,
                      [resource.id]: value,
                    }))
                  }
                />
                <Button
                  size="xs"
                  radius="xl"
                  variant="default"
                  onClick={async () => {
                    const value = Number(minutes[resource.id])
                    await setInterval.execute({
                      id: resource.id,
                      seconds: value > 0 ? Math.round(value * 60) : null,
                    })
                    refetch()
                  }}
                >
                  Schedule
                </Button>
              </Group>
            </Stack>
          </div>
        ))}
      </div>

      {resources.length === 0 && (
        <Text c="dimmed" size="sm">
          No resources are attached yet. Attach one and its contents become
          items you can search.
        </Text>
      )}

      {setInterval.error && (
        <Alert color="red">{setInterval.error.message}</Alert>
      )}
      {sync.error && <Alert color="red">{sync.error.message}</Alert>}
    </Stack>
  )
}
