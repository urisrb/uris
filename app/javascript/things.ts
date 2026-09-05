import { createThings, metaCSRFToken } from '@things/client'
import { actionCableExchange } from '@things/client/actioncable'
import { session } from './hooks/useSession'

export const things = createThings({
  url: '/graphql',
  csrfToken: metaCSRFToken,
  onUnauthorized: () => session.login(),
  subscriptions: actionCableExchange(),
})
