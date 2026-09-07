import type { CSSProperties } from 'react'

export const KIND_ORDER = [
  'pdf',
  'email',
  'xlsx',
  'contact',
  'data',
  'calendar',
  'text',
  'doc',
  'audio',
  'video',
  'image',
  'page',
  'pkpass',
  'file',
] as const

const TONES = new Set<string>(KIND_ORDER)

export function tone(kind: string): string {
  return TONES.has(kind) ? `var(--k-${kind})` : 'var(--k-file)'
}

export function toned(kind: string): CSSProperties {
  return { '--tone': tone(kind) } as CSSProperties
}
