import { describe, expect, test } from 'vitest'
import { asUrl, intentFor, shortly } from '../../app/javascript/add'

const url = (text: string) => asUrl(text)?.toString() ?? null

describe('asUrl', () => {
  test('takes an address with a scheme as written', () => {
    expect(url('https://example.com/a-page')).toBe('https://example.com/a-page')
    expect(url('http://example.com')).toBe('http://example.com/')
  })

  test('assumes https for a bare host', () => {
    expect(url('example.com')).toBe('https://example.com/')
    expect(url('docs.google.com/a')).toBe('https://docs.google.com/a')
  })

  test('leaves anything with a space alone, because that is a search', () => {
    expect(url('march invoice')).toBeNull()
    expect(url(' example.com two')).toBeNull()
  })

  test('does not mistake a bare filename for a host', () => {
    expect(url('file-1.pdf')).toBeNull()
    expect(url('scan-0042.pdf')).toBeNull()
    expect(url('notes.txt')).toBeNull()
    expect(url('march.invoice.xlsx')).toBeNull()
    expect(url('photo.HEIC')).toBeNull()
  })

  test('a scheme says you meant it, whatever the name looks like', () => {
    expect(url('https://file-1.pdf')).toBe('https://file-1.pdf/')
    expect(url('https://report.zip')).toBe('https://report.zip/')
  })

  test('a path means an address even when it ends in a file', () => {
    expect(url('example.com/report.pdf')).toBe('https://example.com/report.pdf')
    expect(url('example.com/a/b.txt')).toBe('https://example.com/a/b.txt')
  })

  test('refuses a scheme that is not the web', () => {
    expect(url('ftp://example.com')).toBeNull()
    expect(url('javascript:alert(1)')).toBeNull()
    expect(url('file:///etc/passwd')).toBeNull()
    expect(url('data:text/html,hi')).toBeNull()
  })

  test('refuses a bare word, which is a search', () => {
    expect(url('invoices')).toBeNull()
    expect(url('')).toBeNull()
    expect(url('   ')).toBeNull()
  })
})

describe('intentFor', () => {
  test('a file-looking path is pulled down, a page is rendered', () => {
    expect(intentFor(new URL('https://example.com/a.pdf'))).toBe('fetch')
    expect(intentFor(new URL('https://example.com/a/b.JPEG'))).toBe('fetch')
    expect(intentFor(new URL('https://example.com/a-page'))).toBe('snapshot')
    expect(intentFor(new URL('https://example.com/'))).toBe('snapshot')
  })

  test('a query string does not turn a page into a file', () => {
    expect(intentFor(new URL('https://example.com/page?x=a.pdf'))).toBe(
      'snapshot',
    )
  })
})

describe('shortly', () => {
  test('drops the scheme and a trailing slash', () => {
    expect(shortly(new URL('https://example.com/'))).toBe('example.com')
    expect(shortly(new URL('https://example.com/a/b'))).toBe('example.com/a/b')
    expect(shortly(new URL('https://example.com/a?q=1'))).toBe(
      'example.com/a?q=1',
    )
  })
})
