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
  IconSparkles,
  IconStar,
  IconStarFilled,
} from '@tabler/icons-react'
import {
  CheckResourceDocument,
  ResourcesDocument,
  SetDefaultInferenceDocument,
  SetDefaultStorageDocument,
  SetSyncIntervalDocument,
  SyncResourceDocument,
} from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useRef, useState } from 'react'
import { useParams } from 'react-router-dom'
import { useTitle } from '../hooks/useTitle'
import { Attach } from './Attach'
import { useAloud, useSay } from './Say'

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
  defaultInference: boolean
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
  useTitle('Resources')

  const { id: landed } = useParams()
  const say = useSay()
  const { data, loading, error, refetch } = useQuery(ResourcesDocument)
  const sync = useAloud(SyncResourceDocument, 'That resource could not sync.')
  const check = useAloud(
    CheckResourceDocument,
    'That resource could not be checked.',
  )
  const takeDrops = useAloud(
    SetDefaultStorageDocument,
    'That could not take drops.',
  )
  const takeQuestions = useAloud(
    SetDefaultInferenceDocument,
    'That could not take questions.',
  )
  const setInterval = useAloud(
    SetSyncIntervalDocument,
    'That schedule could not be set.',
  )
  const [minutes, setMinutes] = useState<Record<string, number | string>>({})
  const [attaching, setAttaching] = useState(false)
  const arrived = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (landed) arrived.current?.scrollIntoView({ block: 'center' })
  }, [landed])

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
            ref={resource.id === landed ? arrived : undefined}
            className="entry"
            data-spine="true"
            data-landed={resource.id === landed}
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
                {resource.defaultInference && (
                  <span
                    className="tag"
                    style={{ '--tone': 'var(--brass)' } as CSSProperties}
                  >
                    answers questions
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
                    const answered = await check.execute({ id: resource.id })

                    if (!answered) return

                    say(
                      answered.checkResource?.ok
                        ? { text: `${resource.key} answers.` }
                        : {
                            text:
                              answered.checkResource?.resource.checkError ??
                              `${resource.key} did not answer.`,
                            wrong: true,
                          },
                    )
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
                    const answered = await sync.execute({ id: resource.id })

                    if (!answered) return

                    say({ text: `${resource.key} is syncing.` })
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
                      const answered = await takeDrops.execute({
                        id: resource.id,
                      })

                      if (!answered) return

                      say({ text: `Drops land in ${resource.key} now.` })
                      refetch()
                    }}
                  >
                    Take drops
                  </Button>
                )}
                {resource.capabilities.includes('inference') && (
                  <Button
                    size="xs"
                    radius="xl"
                    variant="subtle"
                    color="gray"
                    disabled={resource.defaultInference}
                    leftSection={<IconSparkles size={14} />}
                    onClick={async () => {
                      const answered = await takeQuestions.execute({
                        id: resource.id,
                      })

                      if (!answered) return

                      say({ text: `${resource.key} answers questions now.` })
                      refetch()
                    }}
                  >
                    Take questions
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
                    const seconds = value > 0 ? Math.round(value * 60) : null
                    const answered = await setInterval.execute({
                      id: resource.id,
                      seconds,
                    })

                    if (!answered) return

                    say({
                      text: seconds
                        ? `${resource.key} syncs every ${Math.round(seconds / 60)} minutes.`
                        : `${resource.key} syncs on demand only.`,
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
    </Stack>
  )
}
