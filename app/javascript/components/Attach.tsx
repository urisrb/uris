import {
  Alert,
  Anchor,
  Button,
  Checkbox,
  Group,
  Loader,
  Modal,
  Select,
  Stack,
  Text,
  TextInput,
} from '@mantine/core'
import {
  IconAddressBook,
  IconArrowLeft,
  IconArrowRight,
  IconBrandGithub,
  IconBrandGoogleDrive,
  IconBrandNotion,
  IconBrandOnedrive,
  IconBrandSlack,
  IconBucket,
  IconCalendar,
  IconCpu,
  IconFolders,
  IconGitBranch,
  IconMail,
  IconPlug,
  IconPuzzle,
  IconRss,
  IconSearch,
  IconServer2,
  IconWorld,
  IconWorldDownload,
} from '@tabler/icons-react'
import {
  AttachResourceDocument,
  EnrollResourceDocument,
  ResourceTypesDocument,
  type ResourceTypesQuery,
} from '@uris-to/client'
import { useMutation, useQuery } from '@uris-to/client/react'
import { useState } from 'react'

type Attaching = ResourceTypesQuery['resourceTypes'][number]

type Field = Attaching['fields'][number]

type Typed = Record<string, string | boolean>

type Glyph = typeof IconPuzzle

const GLYPHS: Record<string, Glyph> = {
  s3: IconBucket,
  webdav: IconServer2,
  filesystem: IconFolders,
  'oauth-google': IconBrandGoogleDrive,
  'microsoft-graph': IconBrandOnedrive,
  search: IconSearch,
  curl: IconWorldDownload,
  web: IconWorld,
  rss: IconRss,
  imap: IconMail,
  caldav: IconCalendar,
  carddav: IconAddressBook,
  'openai-compatible': IconCpu,
  mcp: IconPlug,
  github: IconBrandGithub,
  notion: IconBrandNotion,
  slack: IconBrandSlack,
  git: IconGitBranch,
}

const GROUPS: { title: string; types: string[] }[] = [
  {
    title: 'Where your files live',
    types: ['s3', 'webdav', 'filesystem', 'oauth-google', 'microsoft-graph'],
  },
  { title: 'The web', types: ['search', 'curl', 'web', 'rss'] },
  {
    title: 'Mail, calendars and contacts',
    types: ['imap', 'caldav', 'carddav'],
  },
  { title: 'Models and tools', types: ['openai-compatible', 'mcp'] },
  { title: 'Where you work', types: ['github', 'notion', 'slack', 'git'] },
]

function glyphFor(type: string): Glyph {
  return GLYPHS[type] ?? IconPuzzle
}

function gist(blurb: string) {
  const first = blurb.split(/(?<=\.)\s/)[0] ?? blurb

  return first.length > 110 ? `${first.slice(0, 107)}…` : first
}

function grouped(types: readonly Attaching[]) {
  const placed = new Set(GROUPS.flatMap((group) => group.types))
  const sections = GROUPS.map((group) => ({
    title: group.title,
    types: group.types.flatMap((name) =>
      types.filter((held) => held.type === name),
    ),
  }))
  const rest = types.filter((held) => !placed.has(held.type))

  return [...sections, { title: 'Everything else', types: rest }].filter(
    (section) => section.types.length > 0,
  )
}

function asked(field: Field, typed: Typed) {
  return (field.shownWhen ?? []).every((condition) =>
    condition.values.includes(`${typed[condition.field] ?? ''}`),
  )
}

function seeded(type: Attaching): Typed {
  return Object.fromEntries(
    type.fields.map((field) => [
      field.name,
      field.kind === 'boolean' ? field.value === 'true' : (field.value ?? ''),
    ]),
  )
}

export function Attach({
  opened,
  onClose,
  onAttached,
}: {
  opened: boolean
  onClose: () => void
  onAttached: () => void
}) {
  const { data, loading } = useQuery(ResourceTypesDocument, {})
  const attach = useMutation(AttachResourceDocument)
  const enroll = useMutation(EnrollResourceDocument)

  const [chosen, setChosen] = useState<string | null>(null)
  const [key, setKey] = useState('')
  const [name, setName] = useState('')
  const [typed, setTyped] = useState<Typed>({})
  const [refused, setRefused] = useState<string | null>(null)
  const [warned, setWarned] = useState<string | null>(null)
  const [link, setLink] = useState<string | null>(null)

  const types = data?.resourceTypes ?? []
  const type = types.find((held) => held.type === chosen) ?? null

  const pick = (next: Attaching) => {
    setChosen(next.type)
    setKey((held) => held || next.type)
    setTyped(seeded(next))
    setRefused(null)
    setWarned(null)
    setLink(null)
  }

  const attaching = attach.loading || enroll.loading
  const shown = (type?.fields ?? []).filter((field) => asked(field, typed))
  const missing = shown.filter(
    (field) => field.required && !`${typed[field.name] ?? ''}`.trim(),
  )
  const ready =
    key.trim().length > 0 && (type?.brokered || missing.length === 0)

  async function connect() {
    if (!type) return

    setRefused(null)
    setWarned(null)

    if (type.brokered) {
      const answered = await enroll.execute({
        type: type.type,
        key: key.trim(),
        name: name.trim() || null,
      })
      const url = answered?.enrollResource?.url

      if (!url) {
        setRefused(enroll.error?.message ?? 'That could not be started.')
        return
      }

      setLink(url)
      return
    }

    const answered = await attach.execute({
      type: type.type,
      key: key.trim(),
      name: name.trim() || null,
      settings: Object.fromEntries(
        shown.map((field) => [field.name, typed[field.name]]),
      ),
    })

    if (!answered?.attachResource?.resource) {
      setRefused(attach.error?.message ?? 'That could not be attached.')
      return
    }

    onAttached()

    if (answered.attachResource.checkError) {
      setWarned(answered.attachResource.checkError)
      return
    }

    onClose()
  }

  const Glyph = type ? glyphFor(type.type) : IconPuzzle

  return (
    <Modal
      opened={opened}
      onClose={onClose}
      title={
        type ? (
          <Button
            variant="subtle"
            color="gray"
            size="compact-sm"
            leftSection={<IconArrowLeft size={15} />}
            onClick={() => setChosen(null)}
            disabled={attaching}
          >
            All resources
          </Button>
        ) : (
          'Attach a resource'
        )
      }
      withCloseButton
      size={type ? 'lg' : 'xl'}
      padding="var(--s5)"
    >
      {loading && !data ? (
        <Loader size="sm" color="var(--brass)" />
      ) : !type ? (
        <Stack gap="var(--s5)">
          <Text c="dimmed" size="sm" maw="60ch">
            A resource is somewhere uris reads from, writes to, or asks
            something of. Pick what you want to connect.
          </Text>

          {grouped(types).map((section) => (
            <section key={section.title} className="attach-group">
              <div className="label">{section.title}</div>
              <div className="attach-grid">
                {section.types.map((held) => {
                  const Icon = glyphFor(held.type)

                  return (
                    <button
                      key={held.type}
                      type="button"
                      className="attach-card"
                      onClick={() => pick(held)}
                    >
                      <span className="attach-icon">
                        <Icon size={22} stroke={1.6} />
                      </span>
                      <span className="attach-copy">
                        <span className="attach-name">{held.label}</span>
                        <span className="attach-gist">{gist(held.blurb)}</span>
                        <span className="attach-meta">
                          {held.brokered
                            ? 'Sign in to connect'
                            : held.fields.length === 0
                              ? 'Nothing to fill in'
                              : held.syncs
                                ? 'Syncs on a schedule'
                                : null}
                        </span>
                      </span>
                      <IconArrowRight
                        className="attach-go"
                        size={16}
                        stroke={1.8}
                      />
                    </button>
                  )
                })}
              </div>
            </section>
          ))}
        </Stack>
      ) : (
        <Stack gap="var(--s5)">
          <div className="attach-head">
            <span className="attach-icon attach-icon-large">
              <Glyph size={28} stroke={1.5} />
            </span>
            <div style={{ minWidth: 0 }}>
              <h2 className="attach-title">{type.label}</h2>
              <Text size="sm" c="dimmed" mt="var(--s1)">
                {type.blurb}
              </Text>
            </div>
          </div>

          <Stack gap="var(--s3)">
            <div className="label">Name it</div>
            <TextInput
              size="md"
              label={type.names}
              description="Unique among resources of this type. It cannot be changed later."
              autoFocus
              withAsterisk
              value={key}
              onChange={(event) => setKey(event.currentTarget.value)}
            />

            <TextInput
              size="md"
              label="Called"
              description="What it is called in listings. Left off, the name above stands in."
              value={name}
              onChange={(event) => setName(event.currentTarget.value)}
            />
          </Stack>

          {type.fields.length > 0 && (
            <Stack gap="var(--s3)">
              <div className="label">
                {type.brokered ? 'Before you sign in' : 'Connection'}
              </div>
              {shown.map((field) => (
                <Asked
                  key={field.name}
                  field={field}
                  value={typed[field.name]}
                  onChange={(next) =>
                    setTyped((held) => ({ ...held, [field.name]: next }))
                  }
                />
              ))}
            </Stack>
          )}

          {refused && <Alert color="red">{refused}</Alert>}

          {warned && (
            <Alert color="yellow" title="Attached, but it did not answer">
              {warned}
            </Alert>
          )}

          {link && (
            <Alert color="yellow" title="One step left">
              Open this to sign in. Nothing exists until you do, and the link
              expires in half an hour. Come back and press Done and it will be
              in the list.
              <div style={{ marginTop: 'var(--s2)' }}>
                <Anchor href={link} target="_blank" rel="noreferrer">
                  {link}
                </Anchor>
              </div>
            </Alert>
          )}

          <Group justify="flex-end" gap="var(--s3)" className="attach-actions">
            <Button
              size="md"
              radius="xl"
              variant="default"
              onClick={() => {
                if (link) onAttached()
                onClose()
              }}
            >
              {warned || link ? 'Done' : 'Cancel'}
            </Button>
            <Button
              size="md"
              radius="xl"
              color="chalk"
              onClick={connect}
              loading={attaching}
              disabled={!ready || link !== null}
            >
              {type.brokered ? 'Get a sign-in link' : 'Attach it'}
            </Button>
          </Group>
        </Stack>
      )}
    </Modal>
  )
}

function Asked({
  field,
  value,
  onChange,
}: {
  field: Field
  value: string | boolean | undefined
  onChange: (next: string | boolean) => void
}) {
  if (field.kind === 'choice') {
    return (
      <Select
        size="md"
        label={field.label}
        description={field.help}
        allowDeselect={false}
        withAsterisk={field.required}
        value={typeof value === 'string' ? value : null}
        onChange={(next) => next !== null && onChange(next)}
        data={(field.options ?? []).map((option) => ({
          value: option.value,
          label: option.label,
        }))}
      />
    )
  }

  if (field.kind === 'boolean') {
    return (
      <Checkbox
        size="md"
        label={field.label}
        description={field.help}
        checked={value === true}
        onChange={(event) => onChange(event.currentTarget.checked)}
      />
    )
  }

  return (
    <TextInput
      size="md"
      label={field.label}
      description={field.help}
      placeholder={field.placeholder ?? undefined}
      type={field.secret ? 'password' : 'text'}
      autoComplete={field.secret ? 'new-password' : 'off'}
      inputMode={field.kind === 'integer' ? 'numeric' : undefined}
      withAsterisk={field.required}
      value={typeof value === 'string' ? value : ''}
      onChange={(event) => onChange(event.currentTarget.value)}
    />
  )
}
