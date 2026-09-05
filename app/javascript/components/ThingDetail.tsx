import { Alert, Button, Code, Group, Loader, Stack, Text } from '@mantine/core'
import { IconArrowLeft, IconCut, IconSparkles } from '@tabler/icons-react'
import {
  AnalyzeThingDocument,
  SplitReferenceDocument,
  ThingDocument,
} from '@thingies/client'
import { useMutation, useQuery } from '@thingies/client/react'
import type { CSSProperties } from 'react'
import { Link, useParams } from 'react-router-dom'
import { KindBadge } from './KindBadge'
import { Thumb } from './Thumb'

export function ThingDetail() {
  const { id = '' } = useParams()
  const { data, loading, error, refetch } = useQuery(ThingDocument, { id })
  const analyze = useMutation(AnalyzeThingDocument)
  const split = useMutation(SplitReferenceDocument)

  if (loading) return <Loader size="sm" color="var(--brass)" />
  if (error) return <Alert color="red">{error.message}</Alert>

  const thing = data?.thing

  if (!thing) return <Text c="dimmed">No such thing.</Text>

  const viewable = thing.references.filter((reference) =>
    /^(image|application\/pdf)/.test(reference.contentType),
  )

  return (
    <Stack gap="var(--s5)">
      <Button
        component={Link}
        to="/"
        variant="subtle"
        color="gray"
        size="compact-sm"
        w="fit-content"
        leftSection={<IconArrowLeft size={15} />}
      >
        Catalog
      </Button>

      <Group justify="space-between" align="flex-start" wrap="nowrap">
        <div style={{ minWidth: 0 }}>
          <h1 className="page-title">{thing.title ?? 'Untitled'}</h1>
          <Group gap="var(--s3)" mt="var(--s3)">
            <KindBadge kind={thing.kind} />
            <span className="eyebrow">
              <span className="figure">{thing.references.length}</span>{' '}
              {thing.references.length === 1 ? 'place' : 'places'} it lives
              {thing.analyzedAt
                ? ` · analyzed ${new Date(thing.analyzedAt).toLocaleString()}`
                : ' · never analyzed'}
            </span>
          </Group>
        </div>

        <Button
          radius="xl"
          color="chalk"
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
        <Group align="flex-start" gap="var(--s4)">
          {viewable.map((reference) => (
            <a
              key={reference.id}
              href={reference.contentUrl}
              target="_blank"
              rel="noreferrer"
            >
              <Thumb
                url={reference.thumbnailUrl}
                kind={thing.kind}
                alt={reference.filename}
                size={230}
              />
            </a>
          ))}
        </Group>
      )}

      {thing.summary && (
        <div className="panel" style={{ padding: 'var(--s4) var(--s5)' }}>
          <Text size="sm" style={{ lineHeight: 1.6, maxWidth: '72ch' }}>
            {thing.summary}
          </Text>
        </div>
      )}

      <Stack gap="var(--s3)">
        <div className="label">Where it lives</div>

        <div className="panel">
          {thing.references.map((reference) => (
            <div
              key={reference.id}
              className="entry"
              data-spine="true"
              style={{ '--tone': 'var(--edge)' } as CSSProperties}
            >
              <div style={{ minWidth: 0 }}>
                <Group gap="var(--s2)">
                  <span className="entry-title">{reference.resource.key}</span>
                  <span className="tag" data-dot="false">
                    {reference.resource.type}
                  </span>
                </Group>

                <Text
                  size="xs"
                  mt="var(--s2)"
                  className="mono"
                  style={{ color: 'var(--soft)', wordBreak: 'break-all' }}
                >
                  {reference.locatorKey ?? '—'}
                </Text>

                <Text size="xs" c="dimmed" mt="var(--s1)">
                  {reference.contentType}
                  {reference.analyzedAt
                    ? ` · analyzed ${new Date(reference.analyzedAt).toLocaleString()}`
                    : ' · not analyzed'}
                </Text>

                {Object.keys(reference.analysis ?? {}).length > 0 && (
                  <Code
                    block
                    mt="var(--s3)"
                    style={{
                      maxHeight: 220,
                      overflow: 'auto',
                      background: 'var(--void)',
                      color: 'var(--soft)',
                    }}
                  >
                    {JSON.stringify(reference.analysis, null, 2)}
                  </Code>
                )}
              </div>

              <Group gap="var(--s2)" wrap="nowrap">
                <Button
                  component="a"
                  href={reference.contentUrl}
                  target="_blank"
                  rel="noreferrer"
                  variant="default"
                  radius="xl"
                  size="xs"
                >
                  Open
                </Button>
                <Button
                  component="a"
                  href={`${reference.contentUrl}?download=1`}
                  variant="default"
                  radius="xl"
                  size="xs"
                >
                  Download
                </Button>
                {thing.references.length > 1 && (
                  <Button
                    variant="subtle"
                    color="gray"
                    radius="xl"
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
            </div>
          ))}
        </div>
      </Stack>
    </Stack>
  )
}
