import { Badge } from '@mantine/core'

const COLORS: Record<string, string> = {
  pdf: 'red',
  image: 'grape',
  text: 'blue',
  data: 'teal',
  email: 'orange',
  xlsx: 'green',
  doc: 'indigo',
  calendar: 'cyan',
  pkpass: 'yellow',
  file: 'gray',
}

export function KindBadge({ kind }: { kind: string }) {
  return (
    <Badge color={COLORS[kind] ?? 'gray'} variant="light" size="sm">
      {kind}
    </Badge>
  )
}
