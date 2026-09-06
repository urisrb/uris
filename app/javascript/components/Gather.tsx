import { Button, Group, Loader, Modal, Stack, Text } from '@mantine/core'
import { IconArrowMerge, IconSearch } from '@tabler/icons-react'
import { MergeItemsDocument, SearchDocument } from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { useEffect, useState } from 'react'
import { useAloud, useSay } from './Say'
import { Thumb } from './Thumb'

interface Props {
  opened: boolean
  onClose: () => void
  id: string
  title: string
  onGathered: () => void
}

export function Gather({ opened, onClose, id, title, onGathered }: Props) {
  const say = useSay()
  const [asking, setAsking] = useState('')
  const [term, setTerm] = useState('')

  const found = useQuery(
    SearchDocument,
    { query: term, kind: null, after: null, limit: 10 },
    { skip: !opened || term.length === 0 },
  )
  const merge = useAloud(MergeItemsDocument, 'Those could not be merged.')

  useEffect(() => {
    if (opened) return

    setAsking('')
    setTerm('')
  }, [opened])

  const others = (found.data?.search.nodes ?? []).filter(
    (item) => item.id !== id,
  )

  const gather = async (other: { id: string; title?: string | null }) => {
    const answered = await merge.execute({ id, otherId: other.id })

    if (!answered) return

    onClose()
    say({
      text: `${other.title ?? 'That item'} is part of ${title} now — every place it lived came with it.`,
    })
    onGathered()
  }

  return (
    <Modal opened={opened} onClose={onClose} title="Merge another item in">
      <Stack gap="var(--s4)">
        <Text size="sm" c="dimmed">
          Every place the item you pick lives moves onto{' '}
          <strong style={{ color: 'var(--text)' }}>{title}</strong>, and the
          item itself goes. Nothing is thrown away — any of those places can be
          split back off afterwards.
        </Text>

        <form
          className="sift"
          onSubmit={(event) => {
            event.preventDefault()
            setTerm(asking.trim())
          }}
        >
          <IconSearch size={15} stroke={1.8} color="var(--muted)" />
          <input
            value={asking}
            onChange={(event) => setAsking(event.currentTarget.value)}
            placeholder="Find the other one"
            aria-label="Find the other one"
          />
        </form>

        {found.loading && <Loader size="xs" color="var(--brass)" />}

        {term && !found.loading && others.length === 0 && (
          <Text size="sm" c="dimmed">
            Nothing else matches that. Only analyzed items turn up in a search.
          </Text>
        )}

        {others.length > 0 && (
          <div className="panel">
            {others.map((other) => (
              <div key={other.id} className="entry">
                <Thumb
                  url={other.thumbnailUrl}
                  kind={other.kind}
                  alt={other.title ?? ''}
                  size={36}
                />

                <div style={{ minWidth: 0 }}>
                  <div className="entry-title">{other.title ?? 'Untitled'}</div>
                  <Text size="xs" c="dimmed">
                    {other.kind}
                  </Text>
                </div>

                <Group gap="var(--s2)" wrap="nowrap">
                  <Button
                    size="xs"
                    radius="xl"
                    variant="default"
                    loading={merge.loading}
                    leftSection={<IconArrowMerge size={14} />}
                    onClick={() => gather(other)}
                  >
                    Merge in
                  </Button>
                </Group>
              </div>
            ))}
          </div>
        )}
      </Stack>
    </Modal>
  )
}
