import { createConsumer } from '@rails/actioncable'
import {
  Client,
  cacheExchange,
  fetchExchange,
  subscriptionExchange,
} from '@urql/core'

const cable = createConsumer()

function getCSRFToken(): string | null {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta?.getAttribute('content') ?? null
}

interface SubscriptionPayload {
  result: Record<string, unknown>
  more: boolean
}

export const client = new Client({
  url: '/graphql',
  exchanges: [
    cacheExchange,
    fetchExchange,
    // Subscriptions ride ActionCable rather than a websocket of their own.
    // The server scopes every topic by tenant, so what arrives here is already
    // narrowed — the client never asks for a stream by name.
    subscriptionExchange({
      forwardSubscription(request) {
        return {
          subscribe(sink) {
            const subscription = cable.subscriptions.create(
              { channel: 'GraphqlChannel' },
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
    }),
  ],
  fetchOptions: () => ({
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': getCSRFToken() || '',
    },
  }),
})
