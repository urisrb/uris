import type { Account } from '@masks/client'
import { useState } from 'react'
import { session } from '../hooks/useSession'

function letters(account: Account | null) {
  const named = account?.name ?? account?.nickname ?? account?.email ?? ''
  const words = named.split(/[\s._@-]+/).filter(Boolean)

  if (words.length === 0) return '?'
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase()

  return `${words[0][0]}${words[1][0]}`.toUpperCase()
}

export function Face({
  account,
  size = 28,
}: {
  account: Account | null
  size?: number
}) {
  const src = session.avatarUrl(account, { size: size * 2 })
  const [broken, setBroken] = useState<string | null>(null)

  if (!src || broken === src) {
    return (
      <span className="face face-letters" style={{ width: size, height: size }}>
        {letters(account)}
      </span>
    )
  }

  return (
    <img
      className="face"
      src={src}
      alt=""
      width={size}
      height={size}
      onError={() => setBroken(src)}
    />
  )
}
