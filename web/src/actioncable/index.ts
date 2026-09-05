import { createConsumer } from '@rails/actioncable'
import { type Exchange, subscriptionExchange } from '@urql/core'

interface SubscriptionPayload {
  result: Record<string, unknown>
  more: boolean
}

export interface ActionCableOptions {
  channel?: string
  url?: string
}

export function actionCableExchange(
  options: ActionCableOptions = {},
): Exchange {
  const { channel = 'GraphqlChannel', url } = options
  const cable = url ? createConsumer(url) : createConsumer()

  return subscriptionExchange({
    forwardSubscription(request) {
      return {
        subscribe(sink) {
          const subscription = cable.subscriptions.create(
            { channel },
            {
              connected() {
                subscription.perform('execute', {
                  query: request.query,
                  variables: request.variables,
                  operationName: request.operationName,
                })
              },
              received(payload: SubscriptionPayload) {
                if (payload.result) {
                  sink.next({
                    data: payload.result.data as Record<string, unknown>,
                  })
                }
                if (!payload.more) {
                  sink.complete()
                }
              },
            },
          )

          return {
            unsubscribe: () => subscription.unsubscribe(),
          }
        },
      }
    },
  })
}
