import { type Looked, lookOf, toned } from '../looks'

export function TypeBadge(looked: Looked) {
  const { tone, label } = lookOf(looked)

  return (
    <span className="tag" style={toned(tone)}>
      {label}
    </span>
  )
}
