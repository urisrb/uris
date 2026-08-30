import {
  Alert,
  Badge,
  Box,
  Button,
  Center,
  Chip,
  Group,
  Loader,
  Progress,
  Stack,
  Table,
  Text,
  Title,
} from '@mantine/core'
import { useEffect, useState } from 'react'
import { CancelRunMutation, RunsQuery } from '../graphql/queries/catalog'
import { useMutation, useQuery } from '../hooks/useGraphQL'

const STATUSES = ['queued', 'running', 'done', 'failed', 'cancelled']

const COLORS: Record<string, string> = {
  queued: 'gray',
  running: 'blue',
  done: 'green',
  failed: 'red',
  cancelled: 'orange',
}

const OPEN = new Set(['queued', 'running'])

function elapsed(startedAt?: string | null, finishedAt?: string | null) {
  if (!startedAt) return '—'

  const from = new Date(startedAt).getTime()
  const to = finishedAt ? new Date(finishedAt).getTime() : Date.now()
  const seconds = Math.max(0, Math.round((to - from) / 1000))

  return seconds < 60
    ? `${seconds}s`
    : `${Math.floor(seconds / 60)}m ${seconds % 60}s`
}

export function Runs() {
  const [status, setStatus] = useState<string | null>(null)
  const { data, loading, error, refetch } = useQuery(RunsQuery, {
    status,
    after: null,
    limit: 50,
  })
  const cancel = useMutation(CancelRunMutation)

  const rows = data?.runs.nodes ?? []
  const busy = rows.some((run) => OPEN.has(run.status))

  useEffect(() => {
    if (!busy) return

    const timer = window.setInterval(() => refetch(), 2000)
    return () => window.clearInterval(timer)
  }, [busy, refetch])

  return (
    <Stack gap="lg">
      <Box>
        <Title order={2}>Runs</Title>
        <Text c="dimmed" size="sm">
          Everything that was started and is not a single request. Open runs
          refresh on their own.
        </Text>
      </Box>

      <Group gap="xs">
        <Chip
          checked={status === null}
          onClick={() => setStatus(null)}
          size="sm"
        >
          all
        </Chip>
        {STATUSES.map((value) => (
          <Chip
            key={value}
            checked={status === value}
            onClick={() => setStatus(status === value ? null : value)}
            size="sm"
          >
            {value}
          </Chip>
        ))}
      </Group>

      {error && <Alert color="red">{error.message}</Alert>}

      <Table highlightOnHover verticalSpacing="sm">
        <Table.Thead>
          <Table.Tr>
            <Table.Th>Kind</Table.Th>
            <Table.Th>Status</Table.Th>
            <Table.Th>Resource</Table.Th>
            <Table.Th>Processed</Table.Th>
            <Table.Th>Elapsed</Table.Th>
            <Table.Th />
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {rows.map((run) => (
            <Table.Tr key={run.id}>
              <Table.Td>
                <Text fw={500}>{run.kind}</Text>
                {run.error && (
                  <Text size="xs" c="red">
                    {run.error}
                  </Text>
                )}
              </Table.Td>
              <Table.Td>
                <Badge
                  color={COLORS[run.status] ?? 'gray'}
                  variant="light"
                  size="sm"
                >
                  {run.status}
                </Badge>
              </Table.Td>
              <Table.Td>
                <Text size="sm" c="dimmed">
                  {run.resource?.key ?? '—'}
                </Text>
              </Table.Td>
              <Table.Td>
                <Text size="sm">{run.processed}</Text>
                {run.status === 'running' && (
                  <Progress value={100} animated size="xs" mt={4} w={80} />
                )}
              </Table.Td>
              <Table.Td>
                <Text size="sm" c="dimmed">
                  {elapsed(run.startedAt, run.finishedAt)}
                </Text>
              </Table.Td>
              <Table.Td>
                {OPEN.has(run.status) && (
                  <Button
                    size="xs"
                    variant="subtle"
                    color="red"
                    onClick={async () => {
                      await cancel.execute({ id: run.id })
                      refetch()
                    }}
                  >
                    Cancel
                  </Button>
                )}
              </Table.Td>
            </Table.Tr>
          ))}
        </Table.Tbody>
      </Table>

      {loading && !data && (
        <Center py="md">
          <Loader size="sm" />
        </Center>
      )}

      {!loading && rows.length === 0 && <Text c="dimmed">No runs yet.</Text>}
    </Stack>
  )
}
