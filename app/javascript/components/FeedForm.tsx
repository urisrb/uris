import {
  Alert,
  Button,
  Group,
  Modal,
  NumberInput,
  Stack,
  Text,
  Textarea,
  TextInput,
} from '@mantine/core'
import { SaveFeedDocument } from '@uris-to/client'
import { useMutation } from '@uris-to/client/react'
import { useEffect, useState } from 'react'

export const EVERY = [
  { label: 'by hand', seconds: 0 },
  { label: 'hourly', seconds: 3600 },
  { label: 'daily', seconds: 86400 },
  { label: 'weekly', seconds: 604800 },
]

export interface Feed {
  id: string
  slug: string
  name?: string | null
  prompt: string
  interval?: number | null
  turns?: number | null
}

interface Props {
  opened: boolean
  onClose: () => void
  feed?: Feed | null
  onSaved: (slug: string) => void
}

export function FeedForm({ opened, onClose, feed, onSaved }: Props) {
  const save = useMutation(SaveFeedDocument)

  const [slug, setSlug] = useState('')
  const [name, setName] = useState('')
  const [prompt, setPrompt] = useState('')
  const [interval, setInterval] = useState(0)
  const [turns, setTurns] = useState<number | string>('')
  const [refused, setRefused] = useState<string | null>(null)

  useEffect(() => {
    if (!opened) return

    setSlug(feed?.slug ?? '')
    setName(feed?.name ?? '')
    setPrompt(feed?.prompt ?? '')
    setInterval(feed?.interval ?? 0)
    setTurns(feed?.turns ?? '')
    setRefused(null)
  }, [opened, feed])

  const keep = async () => {
    const answered = await save.execute({
      id: feed?.id ?? null,
      slug,
      name: name.trim() || null,
      prompt,
      interval,
      turns: Number(turns) > 0 ? Number(turns) : null,
    })

    if (!answered?.saveFeed?.feed) {
      setRefused(save.error?.message ?? 'That feed could not be saved.')
      return
    }

    onClose()
    onSaved(answered.saveFeed.feed.slug)
  }

  return (
    <Modal
      opened={opened}
      onClose={onClose}
      title={feed ? `Edit /${feed.slug}` : 'New feed'}
    >
      <Stack gap="var(--s4)">
        <TextInput
          label="Address"
          description="It becomes a path. Letters, numbers and dashes."
          placeholder="buy"
          value={slug}
          onChange={(event) => setSlug(event.currentTarget.value)}
        />

        <TextInput
          label="Name"
          description="What to call it in a list. Left empty, its address does."
          placeholder="Worth buying"
          value={name}
          onChange={(event) => setName(event.currentTarget.value)}
        />

        <Textarea
          label="Prompt"
          description="What it should go and find, in a sentence."
          placeholder="Find things worth buying from my stores."
          autosize
          minRows={3}
          value={prompt}
          onChange={(event) => setPrompt(event.currentTarget.value)}
        />

        <div>
          <Text size="sm" fw={500}>
            Runs
          </Text>
          <Group gap="var(--s2)" mt="var(--s2)">
            {EVERY.map((option) => (
              <button
                key={option.label}
                type="button"
                className="tag"
                data-dot="false"
                data-on={interval === option.seconds}
                style={{ cursor: 'pointer' }}
                onClick={() => setInterval(option.seconds)}
              >
                {option.label}
              </button>
            ))}
          </Group>
        </div>

        {interval > 0 && (
          <NumberInput
            label="Seconds between runs"
            min={60}
            value={interval}
            onChange={(value) => setInterval(Number(value) || 0)}
          />
        )}

        <NumberInput
          label="Turns it may take"
          description="How many times it may think before it gives up. Left empty, six."
          min={1}
          placeholder="6"
          value={turns}
          onChange={setTurns}
        />

        {refused && <Alert color="red">{refused}</Alert>}

        <Group justify="flex-end">
          <Button variant="default" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={save.loading}
            disabled={!slug || !prompt}
            onClick={keep}
          >
            {feed ? 'Save' : 'Create'}
          </Button>
        </Group>
      </Stack>
    </Modal>
  )
}
