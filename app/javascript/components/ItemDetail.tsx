import { Alert, Button, Code, Group, Loader, Stack, Text } from '@mantine/core'
import { IconArrowLeft, IconCut, IconSparkles } from '@tabler/icons-react'
import {
  AnalyzeItemDocument,
  ItemDocument,
  SplitReferenceDocument,
} from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import type { CSSProperties } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useTitle } from '../hooks/useTitle'
import { KindBadge } from './KindBadge'
import { RunTrail } from './RunTrail'
import { useAloud, useSay } from './Say'
import { Thumb } from './Thumb'

export function ItemDetail() {
  const { id = '' } = useParams()
  const say = useSay()
  const { data, loading, error, refetch } = useQuery(ItemDocument, { id })
  const analyze = useAloud(
    AnalyzeItemDocument,
    'That item could not be analyzed.',
  )
  const split = useAloud(
    SplitReferenceDocument,
    'That place could not be split off.',
  )

  const item = data?.item

  useTitle(item?.title ?? 'Item')

  if (loading) return <Loader size="sm" color="var(--brass)" />
  if (error) return <Alert color="red">{error.message}</Alert>

  if (!item) return <Text c="dimmed">No such item.</Text>

  const viewable = item.references.filter((reference) =>
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
          <h1 className="page-title">{item.title ?? 'Untitled'}</h1>
          <Group gap="var(--s3)" mt="var(--s3)">
            <KindBadge kind={item.kind} />
            <span className="eyebrow">
              <span className="figure">{item.references.length}</span>{' '}
              {item.references.length === 1 ? 'place' : 'places'} it lives
              {item.analyzedAt
                ? ` · analyzed ${new Date(item.analyzedAt).toLocaleString()}`
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
            const answered = await analyze.execute({ id: item.id })

            if (!answered) return

            say({ text: `Analyzing ${item.title ?? 'this item'}.` })
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
                kind={item.kind}
                alt={reference.filename}
                size={230}
              />
            </a>
          ))}
        </Group>
      )}

      {item.summary && (
        <div className="panel" style={{ padding: 'var(--s4) var(--s5)' }}>
          <Text size="sm" style={{ lineHeight: 1.6, maxWidth: '72ch' }}>
            {item.summary}
          </Text>
        </div>
      )}

      <Stack gap="var(--s3)">
        <div className="label">Where it lives</div>

        <div className="panel">
          {item.references.map((reference) => (
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
                {item.references.length > 1 && (
                  <Button
                    variant="subtle"
                    color="gray"
                    radius="xl"
                    size="xs"
                    leftSection={<IconCut size={14} />}
                    onClick={async () => {
                      const answered = await split.execute({ id: reference.id })

                      if (!answered) return

                      say({
                        text: `${reference.resource.key} is its own item now.`,
                      })
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

        <div>
          <div className="eyebrow" style={{ marginBottom: 'var(--s3)' }}>
            Analysis
          </div>
          <RunTrail
            itemId={item.id}
            empty="This item has not been analyzed yet."
          />
        </div>
      </Stack>
    </Stack>
  )
}
