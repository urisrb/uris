const QUESTION_WORDS =
  /^(how|what|when|where|why|who|whom|whose|which|can|could|should|would|will|is|are|was|were|do|does|did|has|have|am|may|might|shall)\b/i

export type Seeking = 'search' | 'ask'

export function seekingFor(text: string): Seeking {
  const said = text.trim()

  if (said.endsWith('?')) return 'ask'
  if (said.split(/\s+/).length < 3) return 'search'

  return QUESTION_WORDS.test(said) ? 'ask' : 'search'
}
