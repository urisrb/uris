import { createUris, metaCSRFToken } from '@uris/client'
import { actionCableExchange } from '@uris/client/actioncable'
import { session } from './hooks/useSession'

export const client = createUris({
  url: '/graphql',
  csrfToken: metaCSRFToken,
  onUnauthorized: () => session.login(),
  subscriptions: actionCableExchange(),
})
