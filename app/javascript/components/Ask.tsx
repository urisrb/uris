import { Button, Text } from '@mantine/core'
import { IconArrowRight, IconSparkles } from '@tabler/icons-react'
import {
  AnalysisProgressedDocument,
  AskCatalogDocument,
  AskedDocument,
} from '@uris-to/client'
import { useQuery, useSubscription } from '@uris-to/client/react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { AnswerText } from './Answer'
import { Progress } from './FeedHead'
import { type Row, Rows } from './Rows'
import { RUN_OPEN } from './RunLog'
import { useAloud } from './Say'

interface Asking {
  feedId: string
  analysisId: string
  createdAt: string
}

export function Ask({ onAsked }: { onAsked?: () => void }) {
  const [question, setQuestion] = useState('')
  const [asking, setAsking] = useState<Asking | null>(null)
  const ask = useAloud(AskCatalogDocument, 'That question could not be asked.')

  const submit = async () => {
    const text = question.trim()

    if (!text) return

    const answered = await ask.execute({ question: text })
    const held = answered?.askCatalog

    if (!held) return

    setAsking({
      feedId: held.feed.id,
      analysisId: held.analysis.id,
      createdAt: held.analysis.createdAt,
    })
    setQuestion('')
    onAsked?.()
  }

  return (
    <section className="ask">
      <form
        className="ask-bar"
        onSubmit={(event) => {
          event.preventDefault()
          submit()
        }}
      >
        <IconSparkles size={17} stroke={1.7} color="var(--brass)" />
        <input
          value={question}
          onChange={(event) => setQuestion(event.currentTarget.value)}
          placeholder="Ask anything — how much was the roof inspection?"
          aria-label="Ask a question about your catalog"
          maxLength={500}
        />
        <Button
          type="submit"
          radius="xl"
          color="chalk"
          size="compact-md"
          loading={ask.loading}
          disabled={!question.trim()}
          rightSection={<IconArrowRight size={15} />}
        >
          Ask
        </Button>
      </form>

      {asking && (
        <Answer key={asking.analysisId} asking={asking} onSettled={onAsked} />
      )}
    </section>
  )
}

function Answer({
  asking,
  onSettled,
}: {
  asking: Asking
  onSettled?: () => void
}) {
  const { data, refetch } = useQuery(AskedDocument, { id: asking.feedId })
  const { data: progressed } = useSubscription(AnalysisProgressedDocument, {
    id: asking.analysisId,
  })

  const pass = data?.feed?.analyses.find(
    (held) => held.id === asking.analysisId,
  )
  const status =
    progressed?.analysisProgressed.analysis.status ?? pass?.status ?? 'queued'
  const open = RUN_OPEN.has(status)

  useEffect(() => {
    if (open) return

    refetch()
    onSettled?.()
  }, [open, refetch, onSettled])

  useEffect(() => {
    if (!open) return

    const tick = window.setInterval(() => refetch(), 4000)

    return () => window.clearInterval(tick)
  }, [open, refetch])

  const question = data?.feed?.title ?? ''
  const cited = (data?.feed?.connected ?? []) as Row[]

  return (
    <div className="ask-answer">
      <div className="ask-question">
        <Link to={`/items/${asking.feedId}`} className="plain">
          {question}
        </Link>
      </div>

      {open ? (
        <Progress
          pass={{
            id: asking.analysisId,
            cause: 'ask',
            status,
            turns: pass?.turns,
            createdAt: asking.createdAt,
          }}
        />
      ) : pass?.status === 'done' && pass.said ? (
        <>
          <AnswerText said={pass.said} cited={cited} />
          {cited.length > 0 && <Rows rows={cited} />}
        </>
      ) : (
        <Text size="sm" style={{ color: 'var(--bad)' }}>
          {pass?.error ?? 'It could not answer that.'}
        </Text>
      )}
    </div>
  )
}
