import { KIND_ORDER, toned } from '../kinds'

export function Spectrum() {
  return (
    <div className="spectrum">
      {KIND_ORDER.map((kind) => (
        <span key={kind} style={toned(kind)} />
      ))}
    </div>
  )
}
