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
} from '@thingies/client'
import { useMutation, useQuery } from '@thingies/client/react'
import { type CSSProperties, useState } from 'react'

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
  thingsCount: number
  capabilities: string[]
  syncInterval?: number | null
  syncedAt?: string | null
  nextSyncAt?: string | null
}

function toneFor(resource: Resource) {
  if (resource.syncing) return 'var(--k-text)'
  if (!resource.checkedAt) return 'var(--k-file)'

  return resource.healthy ? 'var(--k-data)' : 'var(--k-pdf)'
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

  if (loading && !data) return <Loader size="sm" color="var(--brass)" />
  if (error) return <Alert color="red">{error.message}</Alert>

  const resources = (data?.resources ?? []) as Resource[]

  return (
    <Stack gap={22}>
      <div>
        <h1
          className="wordmark"
          style={{ fontSize: 'clamp(1.9rem, 4vw, 2.6rem)', margin: 0 }}
        >
          Resources
        </h1>
        <div className="eyebrow" style={{ marginTop: 8 }}>
          The places your things live, and what each one can be asked to do
        </div>
      </div>

      <div className="panel">
        {resources.map((resource) => (
          <div
            key={resource.id}
            className="entry"
            data-static="true"
            style={
              {
                '--tone': toneFor(resource),
                alignItems: 'flex-start',
                gridTemplateColumns: '3px minmax(0, 1fr) auto',
                padding: '16px 18px 16px 0',
              } as CSSProperties
            }
          >
            <div style={{ minWidth: 0 }}>
              <Group gap={10} wrap="wrap">
                <span className="entry-title">{resource.key}</span>
                <span
                  className="tag"
                  style={{ '--tone': 'var(--edge)' } as CSSProperties}
                >
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

              <Text size="sm" c="dimmed" mt={6}>
                {resource.name ?? '—'} ·{' '}
                <span className="figure">
                  {resource.thingsCount.toLocaleString()}
                </span>{' '}
                things · {resource.capabilities.join(', ')}
              </Text>

              <Text size="xs" c="dimmed" mt={3}>
                {schedule(resource)}
                {resource.syncedAt &&
                  ` · last ${new Date(resource.syncedAt).toLocaleString()}`}
              </Text>

              {resource.checkError && (
                <Text size="xs" mt={6} style={{ color: 'var(--k-pdf)' }}>
                  {resource.checkError}
                </Text>
              )}
            </div>

            <Stack gap={8} align="flex-end">
              <Group gap={8} wrap="nowrap">
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

              <Group gap={8} wrap="nowrap">
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
          things you can search.
        </Text>
      )}

      {setInterval.error && (
        <Alert color="red">{setInterval.error.message}</Alert>
      )}
      {sync.error && <Alert color="red">{sync.error.message}</Alert>}
    </Stack>
  )
}
