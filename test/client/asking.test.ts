import { describe, expect, test } from 'vitest'
import { seekingFor } from '../../app/javascript/asking'

describe('seekingFor', () => {
  test('a question mark asks, however short', () => {
    expect(seekingFor('weather?')).toBe('ask')
    expect(seekingFor('  roof inspection cost?  ')).toBe('ask')
  })

  test('a sentence that opens like a question asks', () => {
    expect(seekingFor('how much was the roof inspection')).toBe('ask')
    expect(seekingFor('When is the Acme invoice due')).toBe('ask')
    expect(seekingFor('can you check the weather in toronto')).toBe('ask')
  })

  test('a few words, or words that do not ask, search', () => {
    expect(seekingFor('acme invoice')).toBe('search')
    expect(seekingFor('what')).toBe('search')
    expect(seekingFor('march invoices from acme')).toBe('search')
  })
})
