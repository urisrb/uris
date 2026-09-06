// Four slashes — the character a URI is built out of, and the one a feed lives behind
// in uris.to/buy. Drawn in kind colours because the catalog tints items the same way,
// so the mark is the product's own palette rather than a decoration beside it.
const SLASHES = [
  { x: 2, tone: 'var(--k-pdf)' },
  { x: 9, tone: 'var(--k-contact)' },
  { x: 16, tone: 'var(--k-text)' },
  { x: 23, tone: 'var(--k-image)' },
]

export function Mark({ size = 26 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 28 28"
      fill="none"
      role="img"
      aria-label="uris"
    >
      {SLASHES.map((slash) => (
        <line
          key={slash.x}
          x1={slash.x}
          y1="21"
          x2={slash.x + 4}
          y2="7"
          stroke={slash.tone}
          strokeWidth="3"
          strokeLinecap="round"
        />
      ))}
    </svg>
  )
}
