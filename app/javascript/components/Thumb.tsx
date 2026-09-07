import {
  IconCalendarEvent,
  IconFile,
  IconFileSpreadsheet,
  IconFileText,
  IconFileTypeDoc,
  IconFileTypePdf,
  IconMail,
  IconMovie,
  IconMusic,
  IconPhoto,
  IconTable,
  IconTicket,
  IconUser,
  IconWorld,
} from '@tabler/icons-react'
import { useState } from 'react'
import { toned } from '../kinds'

const GLYPHS: Record<string, typeof IconFile> = {
  pdf: IconFileTypePdf,
  image: IconPhoto,
  text: IconFileText,
  data: IconTable,
  email: IconMail,
  xlsx: IconFileSpreadsheet,
  doc: IconFileTypeDoc,
  audio: IconMusic,
  video: IconMovie,
  calendar: IconCalendarEvent,
  contact: IconUser,
  page: IconWorld,
  pkpass: IconTicket,
}

interface Props {
  url?: string | null
  kind: string
  alt: string
  size: number
}

export function Thumb({ url, kind, alt, size }: Props) {
  const [broken, setBroken] = useState<string | null>(null)

  if (url && broken !== url) {
    return (
      <img
        src={url}
        alt={alt}
        width={size}
        height={size}
        loading="lazy"
        className="thumb"
        style={{ width: size, height: size }}
        onError={() => setBroken(url)}
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

export function Cover({ url, kind, alt }: Omit<Props, 'size'>) {
  const [broken, setBroken] = useState<string | null>(null)

  if (url && broken !== url) {
    return (
      <img
        src={url}
        alt={alt}
        loading="lazy"
        className="card-figure"
        onError={() => setBroken(url)}
      />
    )
  }

  const Glyph = GLYPHS[kind] ?? IconFile

  return (
    <div className="card-blank" style={toned(kind)}>
      <Glyph size={30} stroke={1.4} />
    </div>
  )
}
