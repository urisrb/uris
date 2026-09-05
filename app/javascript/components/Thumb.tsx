import {
  IconCalendarEvent,
  IconFile,
  IconFileSpreadsheet,
  IconFileText,
  IconFileTypeDoc,
  IconFileTypePdf,
  IconMail,
  IconPhoto,
  IconTable,
  IconTicket,
  IconUser,
} from '@tabler/icons-react'
import { toned } from '../kinds'

const GLYPHS: Record<string, typeof IconFile> = {
  pdf: IconFileTypePdf,
  image: IconPhoto,
  text: IconFileText,
  data: IconTable,
  email: IconMail,
  xlsx: IconFileSpreadsheet,
  doc: IconFileTypeDoc,
  calendar: IconCalendarEvent,
  contact: IconUser,
  pkpass: IconTicket,
}

interface Props {
  url?: string | null
  kind: string
  alt: string
  size: number
}

export function Thumb({ url, kind, alt, size }: Props) {
  if (url) {
    return (
      <img
        src={url}
        alt={alt}
        width={size}
        height={size}
        loading="lazy"
        className="thumb"
        style={{ width: size, height: size }}
      />
    )
  }

  const Glyph = GLYPHS[kind] ?? IconFile

  return (
    <div
      className="thumb-blank"
      style={{ ...toned(kind), width: size, height: size }}
    >
      <Glyph size={Math.round(size * 0.42)} stroke={1.5} />
    </div>
  )
}
