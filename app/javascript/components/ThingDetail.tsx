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
import { toned } from '../kinds'
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
    <Stack gap={24}>
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
          <h1
            className="wordmark"
            style={{ fontSize: 'clamp(1.7rem, 3.6vw, 2.4rem)', margin: 0 }}
          >
            {thing.title ?? 'Untitled'}
          </h1>
          <Group gap={10} mt={12}>
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
        <Group align="flex-start" gap={14}>
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
        <div
          className="panel"
          style={{ padding: '18px 20px', ...toned(thing.kind) }}
        >
          <Text size="sm" style={{ lineHeight: 1.6, maxWidth: '72ch' }}>
            {thing.summary}
          </Text>
        </div>
      )}

      <Stack gap={12}>
        <div className="rail-label" style={{ padding: 0 }}>
          Where it lives
        </div>

        <div className="panel">
          {thing.references.map((reference) => (
            <div
              key={reference.id}
              className="entry"
              data-static="true"
              style={
                {
                  '--tone': 'var(--edge)',
                  gridTemplateColumns: '3px minmax(0, 1fr) auto',
                  alignItems: 'flex-start',
                  padding: '16px 18px 16px 0',
                } as CSSProperties
              }
            >
              <div style={{ minWidth: 0 }}>
                <Group gap={10}>
                  <span className="entry-title">{reference.resource.key}</span>
                  <span
                    className="tag"
                    style={{ '--tone': 'var(--edge)' } as CSSProperties}
                  >
                    {reference.resource.type}
                  </span>
                </Group>

                <Text
                  size="xs"
                  mt={6}
                  className="mono"
                  style={{ color: 'var(--soft)', wordBreak: 'break-all' }}
                >
                  {reference.locatorKey ?? '—'}
                </Text>

                <Text size="xs" c="dimmed" mt={4}>
                  {reference.contentType}
                  {reference.analyzedAt
                    ? ` · analyzed ${new Date(reference.analyzedAt).toLocaleString()}`
                    : ' · not analyzed'}
                </Text>

                {Object.keys(reference.analysis ?? {}).length > 0 && (
                  <Code
                    block
                    mt={12}
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

              <Group gap={8} wrap="nowrap">
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
