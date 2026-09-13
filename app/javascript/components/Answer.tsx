import type { AnchorHTMLAttributes } from 'react'
import Markdown from 'react-markdown'
import { Link } from 'react-router-dom'
import remarkGfm from 'remark-gfm'
import { hrefFor } from '../looks'
import type { Row } from './Rows'

const CITED = /\[feed\s*:?\s*(\d+)\]/gi
const CITE_SCHEME = 'cite:'

function linked(said: string, cited: readonly Row[]) {
  const named = new Map(cited.map((row) => [row.id, row]))

  return said.replace(CITED, (_whole, id: string) => {
    const row = named.get(id)
    if (!row) return ''

    const label = (row.title ?? row.key ?? `feed ${id}`).replace(/[[\]]/g, '')

    return ` [${label}](${CITE_SCHEME}${id})`
  })
}

function allowed(url: string) {
  if (url.startsWith(CITE_SCHEME)) return url

  try {
    const parsed = new URL(url, 'http://relative.invalid')

    return ['http:', 'https:', 'mailto:'].includes(parsed.protocol) ? url : ''
  } catch {
    return ''
  }
}

export function AnswerText({
  said,
  cited,
}: {
  said: string
  cited: readonly Row[]
}) {
  const rows = new Map(cited.map((row) => [row.id, row]))

  return (
    <div className="answer">
      <Markdown
        remarkPlugins={[remarkGfm]}
        urlTransform={allowed}
        components={{
          a: ({
            href = '',
            children,
          }: AnchorHTMLAttributes<HTMLAnchorElement>) => {
            if (href.startsWith(CITE_SCHEME)) {
              const row = rows.get(href.slice(CITE_SCHEME.length))

              return row ? (
                <Link to={hrefFor(row)} className="ask-cite">
                  {children}
                </Link>
              ) : (
                children
              )
            }

            if (!href) return children

            return (
              <a href={href} target="_blank" rel="noreferrer noopener">
                {children}
              </a>
            )
          },
          img: () => null,
        }}
      >
        {linked(said, cited)}
      </Markdown>
    </div>
  )
}
