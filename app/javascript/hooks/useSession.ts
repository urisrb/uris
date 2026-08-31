import { type Account, createSession, type Status } from '@masks/client'
import { useCallback, useEffect, useState } from 'react'

export const session = createSession({ basePath: '/auth' })

interface SessionState {
  account: Account | null
  status: Status | null
  loading: boolean
  error: Error | null
}

export function useSession() {
  const [state, setState] = useState<SessionState>({
    account: null,
    status: null,
    loading: true,
    error: null,
  })

  useEffect(() => {
    let live = true

    session
      .status()
      .then((status) => {
        if (!live) return

        setState({
          account: status.state === 'signed_in' ? status.account : null,
          status,
          loading: false,
          error: null,
        })
      })
      .catch((error: Error) => {
        if (live)
          setState({ account: null, status: null, loading: false, error })
      })

    return () => {
      live = false
    }
  }, [])

  const login = useCallback(() => session.login(), [])
  const connect = useCallback(() => session.handshake(), [])
  const logout = useCallback(async () => {
    await session.logout()
    window.location.assign('/')
  }, [])
  const logoutEverywhere = useCallback(async () => {
    await session.logout({ everywhere: true })
    window.location.assign('/')
  }, [])

  return { ...state, login, logout, logoutEverywhere, connect }
}
