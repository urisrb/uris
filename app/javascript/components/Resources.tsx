import {
  Alert,
  Badge,
  Box,
  Button,
  Card,
  Group,
  Loader,
  NumberInput,
  Stack,
  Text,
  Title,
  Tooltip,
} from '@mantine/core'
import {
  IconCheck,
  IconRefresh,
  IconStar,
  IconStarFilled,
} from '@tabler/icons-react'
import { useState } from 'react'
import {
  CheckResourceMutation,
  ResourcesQuery,
  SetDefaultStorageMutation,
  SetSyncIntervalMutation,
  SyncResourceMutation,
} from '../graphql/queries/catalog'
import { useMutation, useQuery } from '../hooks/useGraphQL'

function Health({
  healthy,
  checkedAt,
  checkError,
}: {
  healthy: boolean
  checkedAt?: string | null
  checkError?: string | null
}) {
  if (!checkedAt) {
    return (
      <Badge color="gray" variant="light" size="sm">
        never checked
      </Badge>
    )
  }

  return (
    <Tooltip
      label={checkError ?? `checked ${new Date(checkedAt).toLocaleString()}`}
    >
      <Badge color={healthy ? 'green' : 'red'} variant="light" size="sm">
        {healthy ? 'reachable' : 'failing'}
      </Badge>
    </Tooltip>
  )
}

export function Resources() {
  const { data, loading, error, refetch } = useQuery(ResourcesQuery)
  const sync = useMutation(SyncResourceMutation)
  const check = useMutation(CheckResourceMutation)
  const setDefault = useMutation(SetDefaultStorageMutation)
  const setInterval = useMutation(SetSyncIntervalMutation)
  const [minutes, setMinutes] = useState<Record<string, number | string>>({})

  if (loading && !data) return <Loader size="sm" />
  if (error) return <Alert color="red">{error.message}</Alert>

  return (
    <Stack gap="lg">
      <Box>
        <Title order={2}>Resources</Title>
        <Text c="dimmed" size="sm">
          The places things live, and the capabilities they can be asked for.
        </Text>
      </Box>

      {data?.resources.map((resource) => (
        <Card key={resource.id} withBorder>
          <Group justify="space-between" align="flex-start" wrap="nowrap">
            <Box>
              <Group gap="xs">
                <Badge variant="outline">{resource.type}</Badge>
                <Text fw={600}>{resource.key}</Text>
                {resource.defaultStorage && (
                  <Badge color="yellow" variant="light" size="sm">
                    default storage
                  </Badge>
                )}
                <Health
                  healthy={resource.healthy}
                  checkedAt={resource.checkedAt}
                  checkError={resource.checkError}
                />
                {resource.syncing && (
                  <Badge color="blue" variant="light" size="sm">
                    syncing
                  </Badge>
                )}
              </Group>

              <Text size="sm" c="dimmed" mt={4}>
                {resource.name ?? '—'} · {resource.thingsCount} things ·{' '}
                {resource.capabilities.join(', ')}
              </Text>

              <Text size="xs" c="dimmed" mt={2}>
                {resource.syncInterval
                  ? `every ${Math.round(resource.syncInterval / 60)} min · next ${
                      resource.nextSyncAt
                        ? new Date(resource.nextSyncAt).toLocaleTimeString()
                        : '—'
                    }`
                  : 'on demand only'}
                {resource.syncedAt &&
                  ` · last ${new Date(resource.syncedAt).toLocaleString()}`}
              </Text>

              {resource.checkError && (
                <Text size="xs" c="red" mt={4}>
                  {resource.checkError}
                </Text>
              )}
            </Box>

            <Stack gap="xs" align="flex-end">
              <Group gap="xs" wrap="nowrap">
                <Button
                  size="xs"
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
                    variant="subtle"
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
                    Default
                  </Button>
                )}
              </Group>

              <Group gap="xs" wrap="nowrap">
                <NumberInput
                  size="xs"
                  w={110}
                  min={1}
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
          </Group>
        </Card>
      ))}

      {setInterval.error && (
        <Alert color="red">{setInterval.error.message}</Alert>
      )}
      {sync.error && <Alert color="red">{sync.error.message}</Alert>}
    </Stack>
  )
}
