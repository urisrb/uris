import { useState } from 'react'
import { type Looked, lookOf, toned } from '../looks'

interface Props {
  url?: string | null
  looked: Looked
  alt: string
  size: number
}

export function Thumb({ url, looked, alt, size }: Props) {
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

  const { tone, glyph: Glyph } = lookOf(looked)

  return (
    <div
      className="thumb-blank"
      style={{ ...toned(tone), width: size, height: size }}
    >
      <Glyph size={Math.round(size * 0.42)} stroke={1.5} />
    </div>
  )
}

export function Cover({ url, looked, alt }: Omit<Props, 'size'>) {
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

  const { tone, glyph: Glyph } = lookOf(looked)

  return (
    <div className="card-blank" style={toned(tone)}>
      <Glyph size={30} stroke={1.4} />
    </div>
  )
}
