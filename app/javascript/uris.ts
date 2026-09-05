import { createUris, metaCSRFToken } from '@uris-to/client'
import { actionCableExchange } from '@uris-to/client/actioncable'
import { session } from './hooks/useSession'

export const client = createUris({
  url: '/graphql',
  csrfToken: metaCSRFToken,
  onUnauthorized: () => session.login(),
  subscriptions: actionCableExchange(),
})
