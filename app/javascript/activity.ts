export interface Named {
  id: string
  key: string
  title?: string | null
}

export interface Happening {
  id: string
  actor: string
  actorName?: string | null
  via?: string | null
  told?: string | null
  feed?: Named | null
  analysis?: { id: string; cause: string } | null
  workingOn?: Named | null
  channel: string
  action: string
  status: string
  scope?: string | null
  remoteIp?: string | null
  requestId?: string | null
  durationMs?: number | null
  detail?: string | null
  arguments: Record<string, unknown>
  createdAt: string
}

export interface Line {
  event: Happening
  times: number
}

export type Entry =
  | {
      kind: 'run'
      key: string
      cause: string
      feed: Named | null
      lines: Line[]
    }
  | { kind: 'one'; key: string; line: Line }

const WEIGHT: Record<string, number> = { ok: 0, denied: 1, error: 2 }

export function worst(statuses: string[]) {
  return statuses.reduce(
    (held, status) =>
      (WEIGHT[status] ?? 0) > (WEIGHT[held] ?? 0) ? status : held,
    'ok',
  )
}

function same(a: Happening, b: Happening) {
  return (
    a.channel === b.channel &&
    a.action === b.action &&
    a.status === b.status &&
    a.actor === b.actor &&
    (a.actorName ?? null) === (b.actorName ?? null) &&
    (a.told ?? null) === (b.told ?? null) &&
    (a.detail ?? null) === (b.detail ?? null) &&
    (a.remoteIp ?? null) === (b.remoteIp ?? null)
  )
}

function folded(events: Happening[]): Line[] {
  return events.reduce<Line[]>((lines, event) => {
    const last = lines.at(-1)

    if (last && same(last.event, event)) last.times += 1
    else lines.push({ event, times: 1 })

    return lines
  }, [])
}

export function sorted(events: readonly Happening[]): Entry[] {
  const runs = new Map<string, Happening[]>()
  const order: Array<{ run: string } | { loose: Happening[] }> = []

  for (const event of events) {
    const run = event.analysis?.id

    if (run) {
      const held = runs.get(run)

      if (held) held.push(event)
      else {
        runs.set(run, [event])
        order.push({ run })
      }

      continue
    }

    const last = order.at(-1)

    if (last && 'loose' in last) last.loose.push(event)
    else order.push({ loose: [event] })
  }

  return order.flatMap((slot): Entry[] => {
    if ('loose' in slot) {
      return folded(slot.loose).map((line) => ({
        kind: 'one',
        key: line.event.id,
        line,
      }))
    }

    const held = runs.get(slot.run) ?? []
    const first = held[0]

    return [
      {
        kind: 'run',
        key: `run:${slot.run}`,
        cause: first?.analysis?.cause ?? '',
        feed: held.find((event) => event.workingOn)?.workingOn ?? null,
        lines: folded([...held].reverse()),
      },
    ]
  })
}
