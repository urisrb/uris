import { useReducedMotion } from '@mantine/hooks'
import { Fragment, useEffect, useState } from 'react'
import { toned, toneOf } from '../looks'

const BEAT = 2100

export function Cycle({ words }: { words: [string, string][] }) {
  const still = useReducedMotion()
  const [at, setAt] = useState(0)

  useEffect(() => {
    if (still) return

    const tick = setInterval(
      () => setAt((was) => (was + 1) % words.length),
      BEAT,
    )

    return () => clearInterval(tick)
  }, [still, words.length])

  if (still) {
    return (
      <span className="cycle-still">
        {words.map(([word, family], index) => (
          <Fragment key={word}>
            <span style={toned(toneOf(family))}>{word}</span>
            {index < words.length - 1 ? ', ' : ''}
          </Fragment>
        ))}
      </span>
    )
  }

  return (
    <span className="cycle">
      <span className="offscreen">
        {words.map(([word]) => word).join(', ')}
      </span>
      {words.map(([word, family], index) => (
        <span
          key={word}
          aria-hidden
          data-on={index === at}
          style={toned(toneOf(family))}
        >
          {word}
        </span>
      ))}
    </span>
  )
}
