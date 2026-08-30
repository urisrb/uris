import { type Account, createSession } from '@masks/client'
import { useCallback, useEffect, useState } from 'react'

export const session = createSession({ basePath: '/auth' })

interface SessionState {
  account: Account | null
  loading: boolean
  error: Error | null
}

export function useSession() {
  const [state, setState] = useState<SessionState>({
    account: null,
    loading: true,
    error: null,
  })

  useEffect(() => {
    let live = true

    session
      .session()
      .then((account) => {
        if (live) setState({ account, loading: false, error: null })
      })
      .catch((error: Error) => {
        if (live) setState({ account: null, loading: false, error })
      })

    return () => {
      live = false
    }
  }, [])

  const login = useCallback(() => session.login(), [])
  const logout = useCallback(async () => {
    await session.logout()
    window.location.assign('/')
  }, [])

  return { ...state, login, logout }
}
