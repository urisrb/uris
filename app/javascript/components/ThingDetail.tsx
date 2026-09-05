import {
  Alert,
  Anchor,
  Badge,
  Box,
  Button,
  Card,
  Code,
  Group,
  Loader,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import { IconArrowLeft, IconCut, IconSparkles } from '@tabler/icons-react'
import {
  AnalyzeThingDocument,
  SplitReferenceDocument,
  ThingDocument,
} from '@things/client'
import { useMutation, useQuery } from '@things/client/react'
import { Link, useParams } from 'react-router-dom'
import { KindBadge } from './KindBadge'
import { Thumb } from './Thumb'

export function ThingDetail() {
  const { id = '' } = useParams()
  const { data, loading, error, refetch } = useQuery(ThingDocument, { id })
  const analyze = useMutation(AnalyzeThingDocument)
  const split = useMutation(SplitReferenceDocument)

  if (loading) return <Loader size="sm" />
  if (error) return <Alert color="red">{error.message}</Alert>

  const thing = data?.thing
  if (!thing) return <Text c="dimmed">No such thing.</Text>

  const viewable = thing.references.filter((reference) =>
    /^(image|application\/pdf)/.test(reference.contentType),
  )

  return (
    <Stack gap="lg">
      <Group>
        <Button
          component={Link}
          to="/"
          variant="subtle"
          leftSection={<IconArrowLeft size={16} />}
        >
          Catalog
        </Button>
      </Group>

      <Group justify="space-between" align="flex-start">
        <Box>
          <Group gap="sm">
            <Title order={2}>{thing.title ?? 'Untitled'}</Title>
            <KindBadge kind={thing.kind} />
          </Group>
          <Text c="dimmed" size="sm">
            {thing.references.length} reference
            {thing.references.length === 1 ? '' : 's'}
            {thing.analyzedAt
              ? ` · analyzed ${new Date(thing.analyzedAt).toLocaleString()}`
              : ' · never analyzed'}
          </Text>
        </Box>

        <Button
          leftSection={<IconSparkles size={16} />}
          loading={analyze.loading}
          onClick={async () => {
            await analyze.execute({ id: thing.id })
            refetch()
          }}
        >
          Analyze
        </Button>
      </Group>

      {viewable.length > 0 && (
        <Group align="flex-start">
          {viewable.map((reference) => (
            <Anchor
              key={reference.id}
              href={reference.contentUrl}
              target="_blank"
              rel="noreferrer"
            >
              <Thumb
                url={reference.thumbnailUrl}
                alt={reference.filename}
                size={220}
              />
            </Anchor>
          ))}
        </Group>
      )}

      {thing.summary && (
        <Card withBorder>
          <Text size="sm">{thing.summary}</Text>
        </Card>
      )}

      <Stack gap="sm">
        <Title order={4}>References</Title>
        {thing.references.map((reference) => (
          <Card key={reference.id} withBorder>
            <Group justify="space-between" align="flex-start" wrap="nowrap">
              <Box style={{ minWidth: 0 }}>
                <Group gap="xs">
                  <Badge variant="outline" size="sm">
                    {reference.resource.type}
                  </Badge>
                  <Text fw={500} truncate>
                    {reference.resource.key}
                  </Text>
                </Group>
                <Code>{reference.locatorKey ?? '—'}</Code>
                <Text size="xs" c="dimmed" mt={4}>
                  {reference.contentType}
                  {reference.analyzedAt
                    ? ` · analyzed ${new Date(reference.analyzedAt).toLocaleString()}`
                    : ' · not analyzed'}
                </Text>
              </Box>

              <Group gap="xs" wrap="nowrap">
                <Button
                  component="a"
                  href={reference.contentUrl}
                  target="_blank"
                  rel="noreferrer"
                  variant="default"
                  size="xs"
                >
                  Open
                </Button>
                <Button
                  component="a"
                  href={`${reference.contentUrl}?download=1`}
                  variant="default"
                  size="xs"
                >
                  Download
                </Button>
                {thing.references.length > 1 && (
                  <Button
                    variant="subtle"
                    size="xs"
                    leftSection={<IconCut size={14} />}
                    onClick={async () => {
                      await split.execute({ id: reference.id })
                      refetch()
                    }}
                  >
                    Split
                  </Button>
                )}
              </Group>
            </Group>

            {Object.keys(reference.analysis ?? {}).length > 0 && (
              <Code block mt="sm" style={{ maxHeight: 220, overflow: 'auto' }}>
                {JSON.stringify(reference.analysis, null, 2)}
              </Code>
            )}
          </Card>
        ))}
      </Stack>
    </Stack>
  )
}
