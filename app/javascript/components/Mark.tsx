const LETTERS = [
  { d: 'M6 8 L3.4 17.6 C3 21 8.9 21 8.6 17.6 L11.2 8', tone: 'var(--k-pdf)' },
  { d: 'M13.9 22 L17.4 8 M17 9.3 L20.4 10.9', tone: 'var(--k-contact)' },
  { d: 'M21.9 22 L25.4 8', tone: 'var(--k-text)' },
  {
    d: 'M31.6 8.6 C29 7.6 28.6 11.4 30 13.4 C31.4 15.4 31.2 19.6 28.4 21.6',
    tone: 'var(--k-image)',
  },
]

export function Mark({ size = 26 }: { size?: number }) {
  return (
    <svg
      width={size * 1.25}
      height={size}
      viewBox="0 0 35 28"
      fill="none"
      role="img"
      aria-label="uris"
    >
      {LETTERS.map((letter) => (
        <path
          key={letter.d}
          d={letter.d}
          stroke={letter.tone}
          strokeWidth="2.7"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      ))}
    </svg>
  )
}
