import { toned } from '../kinds'

export function KindBadge({ kind }: { kind: string }) {
  return (
    <span className="tag" style={toned(kind)}>
      {kind}
    </span>
  )
}
