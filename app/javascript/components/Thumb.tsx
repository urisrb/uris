import { Center, Paper } from '@mantine/core'
import { IconFile } from '@tabler/icons-react'

interface Props {
  url?: string | null
  alt: string
  size: number
}

export function Thumb({ url, alt, size }: Props) {
  if (url) {
    return (
      <img
        src={url}
        alt={alt}
        width={size}
        height={size}
        loading="lazy"
        style={{ objectFit: 'cover', borderRadius: 8, display: 'block' }}
      />
    )
  }

  return (
    <Paper
      w={size}
      h={size}
      bg="var(--mantine-color-default-hover)"
      radius="md"
    >
      <Center h="100%">
        <IconFile size={size / 3} stroke={1.2} opacity={0.4} />
      </Center>
    </Paper>
  )
}
