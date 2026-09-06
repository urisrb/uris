export type Intent = 'snapshot' | 'fetch'

const BARE = /^[\w-]+(\.[\w-]+)+([/:?#]|$)/

const FILE_LIKE =
  /\.(pdf|png|jpe?g|gif|webp|heic|avif|tiff?|txt|md|rtf|csv|tsv|json|xml|xlsx?|ods|docx?|odt|ics|vcf|vcard|pkpass|eml|zip|epub|mp3|mp4|mov|wav)$/i

export function asUrl(text: string): URL | null {
  const trimmed = text.trim()

  if (!trimmed || /\s/.test(trimmed)) return null

  const candidate = /^https?:\/\//i.test(trimmed)
    ? trimmed
    : BARE.test(trimmed)
      ? `https://${trimmed}`
      : null

  if (!candidate) return null

  try {
    const url = new URL(candidate)

    return url.protocol === 'http:' || url.protocol === 'https:' ? url : null
  } catch {
    return null
  }
}

export function intentFor(url: URL): Intent {
  return FILE_LIKE.test(url.pathname) ? 'fetch' : 'snapshot'
}

export function shortly(url: URL): string {
  const trail = `${url.pathname}${url.search}`.replace(/\/$/, '')

  return `${url.host}${trail}`
}
