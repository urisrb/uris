import { Button, Group, Modal, Stack, Text } from '@mantine/core'
import type { ReactNode } from 'react'

interface Props {
  opened: boolean
  onClose: () => void
  onSure: () => void
  title: string
  verb: string
  loading?: boolean
  children: ReactNode
}

export function Sure({
  opened,
  onClose,
  onSure,
  title,
  verb,
  loading,
  children,
}: Props) {
  return (
    <Modal opened={opened} onClose={onClose} title={title} size="md">
      <Stack gap="var(--s4)">
        <Text size="sm" style={{ lineHeight: 1.6 }}>
          {children}
        </Text>

        <Group justify="flex-end" gap="var(--s2)">
          <Button variant="default" onClick={onClose}>
            Cancel
          </Button>
          <Button color="red" loading={loading} onClick={onSure}>
            {verb}
          </Button>
        </Group>
      </Stack>
    </Modal>
  )
}
