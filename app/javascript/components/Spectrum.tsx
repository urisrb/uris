import { FAMILIES, toned, toneOf } from '../looks'

export function Spectrum() {
  return (
    <div className="spectrum">
      {FAMILIES.map((family) => (
        <span key={family} style={toned(toneOf(family))} />
      ))}
    </div>
  )
}
