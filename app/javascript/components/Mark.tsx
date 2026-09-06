const SLASHES = [
  { x: 1.5, tone: 'var(--k-pdf)' },
  { x: 8.5, tone: 'var(--k-contact)' },
  { x: 15.5, tone: 'var(--k-text)' },
  { x: 22.5, tone: 'var(--k-image)' },
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
          y1="22"
          x2={slash.x + 4}
          y2="6"
          stroke={slash.tone}
          strokeWidth="3"
          strokeLinecap="butt"
        />
      ))}
    </svg>
  )
}
