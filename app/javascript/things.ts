import { createThings, metaCSRFToken } from '@thingies/client'
import { actionCableExchange } from '@thingies/client/actioncable'
import { session } from './hooks/useSession'

export const things = createThings({
  url: '/graphql',
  csrfToken: metaCSRFToken,
  onUnauthorized: () => session.login(),
  subscriptions: actionCableExchange(),
})
