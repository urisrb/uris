import {
  Alert,
  Button,
  Group,
  Modal,
  Stack,
  Text,
  Textarea,
  TextInput,
} from '@mantine/core'
import { IconArrowBarToDown, IconFolder, IconPlus } from '@tabler/icons-react'
import {
  AddNoteDocument,
  FetchUrlDocument,
  SnapshotUrlDocument,
} from '@uris-to/client'
import { useMutation } from '@uris-to/client/react'
import {
  type ChangeEvent,
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'
import { Link } from 'react-router-dom'
import { asUrl, type Intent, intentFor, shortly } from '../add'
import { useUploads } from './Uploads'

type Mode = 'link' | 'note' | 'files'

export interface Added {
  key: string
  label: string
  detail: string
  to: string
}

export type Outcome =
  | { ok: true; added: Added }
  | { ok: false; refused: string }

interface Seed {
  mode: Mode
  url?: string
  body?: string
}

interface Adding {
  opened: boolean
  added: Added[]
  addedAt: number | null
  busy: boolean
  open: (seed?: Seed) => void
  close: () => void
  keepUrl: (url: string, intent: Intent) => Promise<Outcome>
  keepNote: (title: string, body: string) => Promise<Outcome>
}

const Context = createContext<Adding | null>(null)

const MODES: { mode: Mode; label: string }[] = [
  { mode: 'link', label: 'A link' },
  { mode: 'note', label: 'A note' },
  { mode: 'files', label: 'Files' },
]

export function useAdd() {
  const held = useContext(Context)

  if (!held) throw new Error('useAdd needs an AddProvider above it')

  return held
}

function typing(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false

  return (
    target.isContentEditable ||
    target instanceof HTMLInputElement ||
    target instanceof HTMLTextAreaElement
  )
}

export function AddProvider({ children }: { children: ReactNode }) {
  const uploads = useUploads()

  const [opened, setOpened] = useState(false)
  const [mode, setMode] = useState<Mode>('link')
  const [url, setUrl] = useState('')
  const [intent, setIntent] = useState<Intent>('snapshot')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [refused, setRefused] = useState<string | null>(null)
  const [added, setAdded] = useState<Added[]>([])
  const [addedAt, setAddedAt] = useState<number | null>(null)

  const note = useMutation(AddNoteDocument)
  const snapshot = useMutation(SnapshotUrlDocument)
  const fetched = useMutation(FetchUrlDocument)

  const busy = note.loading || snapshot.loading || fetched.loading

  const remember = useCallback((entry: Added) => {
    setAdded((held) => [entry, ...held].slice(0, 6))
    setAddedAt(Date.now())
  }, [])

  const keepUrl = useCallback(
    async (given: string, wanted: Intent): Promise<Outcome> => {
      const parsed = asUrl(given)

      if (!parsed) return { ok: false, refused: 'That is not a web address.' }

      const address = parsed.toString()
      const where = shortly(parsed)

      if (wanted === 'snapshot') {
        const answered = await snapshot.execute({ url: address })
        const run = answered?.snapshotUrl?.run

        if (!run)
          return {
            ok: false,
            refused: snapshot.error?.message ?? 'That page could not be taken.',
          }

        const entry = {
          key: run.id,
          label: where,
          detail: 'being rendered',
          to: '/runs',
        }

        remember(entry)

        return { ok: true, added: entry }
      }

      const answered = await fetched.execute({ url: address })
      const run = answered?.fetchUrl?.run

      if (!run)
        return {
          ok: false,
          refused: fetched.error?.message ?? 'That file could not be fetched.',
        }

      const entry = {
        key: run.id,
        label: where,
        detail: 'being fetched',
        to: '/runs',
      }

      remember(entry)

      return { ok: true, added: entry }
    },
    [snapshot, fetched, remember],
  )

  const keepNote = useCallback(
    async (given: string, written: string): Promise<Outcome> => {
      if (!written.trim())
        return { ok: false, refused: 'A note needs something in it.' }

      const answered = await note.execute({
        title: given.trim() || null,
        body: written,
      })
      const item = answered?.addNote?.item

      if (!item)
        return {
          ok: false,
          refused: note.error?.message ?? 'That note could not be kept.',
        }

      const entry = {
        key: item.id,
        label: item.title ?? 'Note',
        detail: 'kept',
        to: `/items/${item.id}`,
      }

      remember(entry)

      return { ok: true, added: entry }
    },
    [note, remember],
  )

  const open = useCallback((seed?: Seed) => {
    setRefused(null)
    setMode(seed?.mode ?? 'link')

    if (seed?.url !== undefined) {
      const parsed = asUrl(seed.url)

      setUrl(seed.url)
      setIntent(parsed ? intentFor(parsed) : 'snapshot')
    }

    if (seed?.body !== undefined) {
      setBody(seed.body)
      setTitle('')
    }

    setOpened(true)
  }, [])

  // Whatever is on the clipboard decides what it becomes: files go the way a
  // drop goes, an address opens on the link, and anything else is a note.
  useEffect(() => {
    const pasted = (event: ClipboardEvent) => {
      if (typing(event.target)) return

      const data = event.clipboardData

      if (!data) return

      if (data.files.length > 0) {
        event.preventDefault()
        uploads.add(data.files)
        return
      }

      const text = data.getData('text/plain')

      if (!text.trim()) return

      event.preventDefault()

      const found = asUrl(text)

      open(
        found
          ? { mode: 'link', url: found.toString() }
          : { mode: 'note', body: text },
      )
    }

    window.addEventListener('paste', pasted)

    return () => window.removeEventListener('paste', pasted)
  }, [uploads.add, open])

  const value = useMemo<Adding>(
    () => ({
      opened,
      added,
      addedAt,
      busy,
      open,
      close: () => setOpened(false),
      keepUrl,
      keepNote,
    }),
    [opened, added, addedAt, busy, open, keepUrl, keepNote],
  )

  async function keep() {
    setRefused(null)

    const outcome =
      mode === 'note' ? await keepNote(title, body) : await keepUrl(url, intent)

    if (!outcome.ok) {
      setRefused(outcome.refused)
      return
    }

    setUrl('')
    setTitle('')
    setBody('')
  }

  return (
    <Context.Provider value={value}>
      {children}

      <Modal
        opened={opened}
        onClose={() => setOpened(false)}
        title="Add to the catalog"
        size="lg"
      >
        <Stack gap="var(--s4)">
          <Group gap="var(--s2)">
            {MODES.map((option) => (
              <button
                key={option.mode}
                type="button"
                className="tag"
                data-dot="false"
                data-on={mode === option.mode}
                style={{ cursor: 'pointer' }}
                onClick={() => {
                  setMode(option.mode)
                  setRefused(null)
                }}
              >
                {option.label}
              </button>
            ))}
          </Group>

          {mode === 'link' && (
            <Address
              url={url}
              intent={intent}
              busy={busy}
              onUrl={setUrl}
              onIntent={setIntent}
              onKeep={keep}
            />
          )}

          {mode === 'note' && (
            <Note
              title={title}
              body={body}
              busy={busy}
              onTitle={setTitle}
              onBody={setBody}
              onKeep={keep}
            />
          )}

          {mode === 'files' && <Files />}

          {refused && <Alert color="red">{refused}</Alert>}

          {added.length > 0 && (
            <div className="added">
              {added.map((entry) => (
                <Link
                  key={entry.key}
                  to={entry.to}
                  className="added-row"
                  onClick={() => setOpened(false)}
                >
                  <span className="added-what">{entry.label}</span>
                  <span className="added-where">{entry.detail}</span>
                </Link>
              ))}
            </div>
          )}
        </Stack>
      </Modal>
    </Context.Provider>
  )
}

function Address({
  url,
  intent,
  busy,
  onUrl,
  onIntent,
  onKeep,
}: {
  url: string
  intent: Intent
  busy: boolean
  onUrl: (value: string) => void
  onIntent: (value: Intent) => void
  onKeep: () => void
}) {
  const parsed = asUrl(url)

  return (
    <>
      <TextInput
        label="Address"
        description="A page to keep as it looks now, or a file to pull down."
        placeholder="https://example.com/a-page"
        autoFocus
        value={url}
        onChange={(event) => {
          const next = event.currentTarget.value
          const found = asUrl(next)

          onUrl(next)
          if (found) onIntent(intentFor(found))
        }}
        onKeyDown={(event) => {
          if (event.key === 'Enter' && parsed && !busy) onKeep()
        }}
      />

      <div>
        <Text size="sm" fw={500}>
          Keep it as
        </Text>
        <Group gap="var(--s2)" mt="var(--s2)">
          <button
            type="button"
            className="tag"
            data-dot="false"
            data-on={intent === 'snapshot'}
            style={{ cursor: 'pointer' }}
            onClick={() => onIntent('snapshot')}
          >
            a rendered page
          </button>
          <button
            type="button"
            className="tag"
            data-dot="false"
            data-on={intent === 'fetch'}
            style={{ cursor: 'pointer' }}
            onClick={() => onIntent('fetch')}
          >
            the file at that address
          </button>
        </Group>
      </div>

      <Group justify="flex-end">
        <Button onClick={onKeep} loading={busy} disabled={!parsed}>
          Add
        </Button>
      </Group>
    </>
  )
}

function Note({
  title,
  body,
  busy,
  onTitle,
  onBody,
  onKeep,
}: {
  title: string
  body: string
  busy: boolean
  onTitle: (value: string) => void
  onBody: (value: string) => void
  onKeep: () => void
}) {
  return (
    <>
      <TextInput
        label="Title"
        description="Left off, the first line names it."
        placeholder="Pelicans"
        value={title}
        onChange={(event) => onTitle(event.currentTarget.value)}
      />

      <Textarea
        label="Note"
        placeholder="Anything worth finding again."
        autoFocus
        autosize
        minRows={5}
        maxRows={16}
        value={body}
        onChange={(event) => onBody(event.currentTarget.value)}
      />

      <Group justify="flex-end">
        <Button onClick={onKeep} loading={busy} disabled={!body.trim()}>
          Keep it
        </Button>
      </Group>
    </>
  )
}

function Files() {
  const { add } = useUploads()
  const loose = useRef<HTMLInputElement>(null)
  const folder = useRef<HTMLInputElement>(null)

  const chosen = (event: ChangeEvent<HTMLInputElement>) => {
    if (event.currentTarget.files?.length) add(event.currentTarget.files)
    event.currentTarget.value = ''
  }

  return (
    <>
      <Text size="sm" c="dimmed">
        Everything you choose is written to your default storage, then indexed.
        Dropping onto the window anywhere does the same, and so does pasting.
      </Text>

      <Group gap="var(--s3)">
        <Button
          variant="default"
          leftSection={<IconArrowBarToDown size={16} stroke={1.6} />}
          onClick={() => loose.current?.click()}
        >
          Choose files
        </Button>
        <Button
          variant="default"
          leftSection={<IconFolder size={16} stroke={1.6} />}
          onClick={() => folder.current?.click()}
        >
          Choose a folder
        </Button>
      </Group>

      <input ref={loose} type="file" multiple hidden onChange={chosen} />
      <input
        ref={folder}
        type="file"
        multiple
        hidden
        onChange={chosen}
        {...({ webkitdirectory: '' } as Record<string, string>)}
      />
    </>
  )
}

export function AddButton() {
  const { open } = useAdd()

  return (
    <Button
      className="head-add"
      color="chalk"
      size="compact-sm"
      radius="xl"
      leftSection={<IconPlus size={15} stroke={2} />}
      onClick={() => open()}
      aria-label="Add to the catalog"
    >
      <span className="head-add-word">Add</span>
    </Button>
  )
}
