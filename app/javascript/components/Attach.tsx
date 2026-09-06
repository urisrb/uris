import {
  Alert,
  Anchor,
  Button,
  Checkbox,
  Group,
  Loader,
  Modal,
  Stack,
  Text,
  TextInput,
} from '@mantine/core'
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
    setTyped(seeded(next))
    setRefused(null)
    setWarned(null)
    setLink(null)
  }

  const attaching = attach.loading || enroll.loading
  const missing = (type?.fields ?? []).filter(
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
      settings: typed,
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

  return (
    <Modal
      opened={opened}
      onClose={onClose}
      title="Attach a resource"
      size="lg"
    >
      {loading && !data ? (
        <Loader size="sm" color="var(--brass)" />
      ) : (
        <Stack gap="var(--s4)">
          <div>
            <Text size="sm" fw={500}>
              What is it
            </Text>
            <Group gap="var(--s2)" mt="var(--s2)">
              {types.map((held) => (
                <button
                  key={held.type}
                  type="button"
                  className="tag"
                  data-dot="false"
                  data-on={chosen === held.type}
                  style={{ cursor: 'pointer' }}
                  onClick={() => pick(held)}
                >
                  {held.label}
                </button>
              ))}
            </Group>
          </div>

          {type && (
            <>
              <Text size="sm" c="dimmed">
                {type.blurb}
              </Text>

              <TextInput
                label={type.names}
                description="Unique among resources of this type. It cannot be changed later."
                autoFocus
                value={key}
                onChange={(event) => setKey(event.currentTarget.value)}
              />

              <TextInput
                label="Called"
                description="What it is called in listings. Left off, the name above stands in."
                value={name}
                onChange={(event) => setName(event.currentTarget.value)}
              />

              {type.fields.map((field) => (
                <Asked
                  key={field.name}
                  field={field}
                  value={typed[field.name]}
                  onChange={(next) =>
                    setTyped((held) => ({ ...held, [field.name]: next }))
                  }
                />
              ))}

              {refused && <Alert color="red">{refused}</Alert>}

              {warned && (
                <Alert color="yellow" title="Attached, but it did not answer">
                  {warned}
                </Alert>
              )}

              {link && (
                <Alert color="yellow" title="One step left">
                  Open this to sign in. Nothing exists until you do, and the
                  link expires in half an hour. Come back and press Done and it
                  will be in the list.
                  <div style={{ marginTop: 'var(--s2)' }}>
                    <Anchor href={link} target="_blank" rel="noreferrer">
                      {link}
                    </Anchor>
                  </div>
                </Alert>
              )}

              <Group justify="flex-end">
                <Button
                  variant="default"
                  onClick={() => {
                    if (link) onAttached()
                    onClose()
                  }}
                >
                  {warned || link ? 'Done' : 'Cancel'}
                </Button>
                <Button
                  onClick={connect}
                  loading={attaching}
                  disabled={!ready || link !== null}
                >
                  {type.brokered ? 'Get a link' : 'Attach'}
                </Button>
              </Group>
            </>
          )}
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
  if (field.kind === 'boolean') {
    return (
      <Checkbox
        label={field.label}
        description={field.help}
        checked={value === true}
        onChange={(event) => onChange(event.currentTarget.checked)}
      />
    )
  }

  return (
    <TextInput
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
