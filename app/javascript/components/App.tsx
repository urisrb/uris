import { Burger, Button, Loader, Menu, Text } from '@mantine/core'
import {
  IconDatabase,
  IconLayoutGrid,
  IconProgressCheck,
  IconSearch,
  IconSettings,
} from '@tabler/icons-react'
import { CatalogDocument } from '@uris-to/client'
import { useQuery } from '@uris-to/client/react'
import { type CSSProperties, useEffect, useState } from 'react'
import {
  Link,
  Route,
  Routes,
  useLocation,
  useNavigate,
  useSearchParams,
} from 'react-router-dom'
import { useSession } from '../hooks/useSession'
import { tone } from '../kinds'
import { Catalog } from './Catalog'
import { Cycle } from './Cycle'
import { ItemDetail } from './ItemDetail'
import { Resources } from './Resources'
import { Runs } from './Runs'
import { Settings } from './Settings'
import { Spectrum } from './Spectrum'
import { UploadsProvider, useUploads } from './Uploads'

const VERBS: [string, string][] = [
  ['make', 'doc'],
  ['see', 'image'],
  ['watch', 'calendar'],
  ['read', 'pdf'],
  ['write', 'text'],
  ['send', 'email'],
  ['buy', 'pkpass'],
  ['share', 'contact'],
  ['keep', 'file'],
]

const SECTIONS = [
  { to: '/', label: 'Catalog', icon: IconLayoutGrid },
  { to: '/resources', label: 'Resources', icon: IconDatabase },
  { to: '/runs', label: 'Runs', icon: IconProgressCheck },
  { to: '/settings', label: 'Settings', icon: IconSettings },
]

export function App() {
  const { account, status, loading, login, logout, logoutEverywhere, connect } =
    useSession()

  if (loading) {
    return (
      <div className="gate">
        <Loader color="var(--brass)" />
      </div>
    )
  }

  if (!account) {
    return (
      <Gate
        unconnected={status?.state === 'handshake_required'}
        enter={status?.state === 'handshake_required' ? connect : login}
      />
    )
  }

  return (
    <UploadsProvider>
      <Shell
        who={account.nickname ?? account.name ?? account.email ?? 'you'}
        tenant={account.tenant?.name}
        logout={logout}
        logoutEverywhere={logoutEverywhere}
      />
    </UploadsProvider>
  )
}

function Gate({
  unconnected,
  enter,
}: {
  unconnected: boolean
  enter: () => void
}) {
  return (
    <div className="gate">
      <div className="gate-inner">
        <div className="wordmark gate-word">items</div>
        <div style={{ marginTop: 'var(--s5)' }}>
          <Spectrum />
        </div>

        <p className="gate-line">
          Everything you <Cycle words={VERBS} />
        </p>

        <p className="gate-tagline">
          {unconnected
            ? 'Connect a sign-in server. It is the front door to all of it.'
            : 'Your items, together. One index across every account you own — searchable, and yours to take back out.'}
        </p>

        <Button
          mt="var(--s6)"
          size="md"
          radius="xl"
          color="chalk"
          onClick={enter}
          styles={{ root: { fontWeight: 600, paddingInline: 'var(--s5)' } }}
        >
          {unconnected ? 'Connect a sign-in server' : 'Sign in'}
        </Button>
      </div>
    </div>
  )
}

function Shell({
  who,
  tenant,
  logout,
  logoutEverywhere,
}: {
  who: string
  tenant?: string | null
  logout: () => void
  logoutEverywhere: () => void
}) {
  const [open, setOpen] = useState(false)

  return (
    <div className="shell">
      <header className="shell-head">
        <Burger
          opened={open}
          onClick={() => setOpen((was) => !was)}
          size="sm"
          color="var(--soft)"
          hiddenFrom="sm"
        />

        <Link
          to="/"
          className="wordmark"
          style={{ fontSize: 'var(--t-title)', textDecoration: 'none' }}
        >
          items
        </Link>

        <Hunt />

        <Menu position="bottom-end" width={210}>
          <Menu.Target>
            <Button variant="subtle" color="gray" size="compact-sm" radius="xl">
              {who}
            </Button>
          </Menu.Target>
          <Menu.Dropdown>
            {tenant && <Menu.Label>{tenant}</Menu.Label>}
            <Menu.Item component={Link} to="/settings">
              Settings
            </Menu.Item>
            <Menu.Item onClick={logout}>Sign out</Menu.Item>
            <Menu.Item onClick={logoutEverywhere}>
              Sign out everywhere
            </Menu.Item>
          </Menu.Dropdown>
        </Menu>
      </header>

      <nav className="shell-rail" data-open={open}>
        <Rail onGo={() => setOpen(false)} />
      </nav>

      <main className="shell-main">
        <Routes>
          <Route path="/" element={<Catalog />} />
          <Route path="/items/:id" element={<ItemDetail />} />
          <Route path="/resources" element={<Resources />} />
          <Route path="/runs" element={<Runs />} />
          <Route
            path="/settings"
            element={
              <Settings
                who={who}
                tenant={tenant}
                logout={logout}
                logoutEverywhere={logoutEverywhere}
              />
            }
          />
        </Routes>
      </main>
    </div>
  )
}

function Hunt() {
  const [params, setParams] = useSearchParams()
  const navigate = useNavigate()
  const term = params.get('q') ?? ''
  const [draft, setDraft] = useState(term)

  useEffect(() => setDraft(term), [term])

  return (
    <form
      className="hunt"
      onSubmit={(event) => {
        event.preventDefault()

        const next = new URLSearchParams(params)

        if (draft.trim()) next.set('q', draft.trim())
        else next.delete('q')

        if (window.location.pathname === '/') setParams(next)
        else navigate(`/?${next.toString()}`)
      }}
    >
      <IconSearch size={16} stroke={1.8} color="var(--muted)" />
      <input
        value={draft}
        onChange={(event) => setDraft(event.currentTarget.value)}
        placeholder="Search everything you own"
        aria-label="Search everything you own"
      />
      {term && (
        <Button
          variant="subtle"
          color="gray"
          size="compact-xs"
          onClick={() => {
            const next = new URLSearchParams(params)
            next.delete('q')
            setDraft('')
            setParams(next)
          }}
        >
          Clear
        </Button>
      )}
    </form>
  )
}

function Rail({ onGo }: { onGo: () => void }) {
  const location = useLocation()
  const [params] = useSearchParams()
  const { settledAt } = useUploads()
  const { data, refetch } = useQuery(CatalogDocument, {
    kind: null,
    after: null,
    limit: 1,
  })

  useEffect(() => {
    if (settledAt) refetch()
  }, [settledAt, refetch])

  const kind = params.get('kind')
  const kinds = data?.kinds ?? []
  const total = kinds.reduce((sum, entry) => sum + entry.count, 0)

  const linkTo = (next: string | null) => {
    const held = new URLSearchParams(params)

    if (next) held.set('kind', next)
    else held.delete('kind')

    const query = held.toString()

    return query ? `/?${query}` : '/'
  }

  return (
    <>
      <div className="rail-group">
        {SECTIONS.map(({ to, label, icon: Icon }) => {
          const on =
            to === '/'
              ? location.pathname === '/'
              : location.pathname.startsWith(to)

          return (
            <Link
              key={to}
              to={to}
              className="rail-link"
              aria-current={on ? 'page' : undefined}
              onClick={onGo}
            >
              <Icon size={17} stroke={1.6} />
              {label}
            </Link>
          )
        })}
      </div>

      <div className="rail-group">
        <div className="rail-label">Kinds</div>

        <Link
          to={linkTo(null)}
          className="kind-link"
          style={{ '--tone': 'var(--soft)' } as CSSProperties}
          data-on={!kind}
          onClick={onGo}
        >
          <span>everything</span>
          <span className="figure">{total.toLocaleString()}</span>
        </Link>

        {kinds.map((entry) => (
          <Link
            key={entry.kind}
            to={linkTo(entry.kind === kind ? null : entry.kind)}
            className="kind-link"
            style={{ '--tone': tone(entry.kind) } as CSSProperties}
            data-on={entry.kind === kind}
            onClick={onGo}
          >
            <span>{entry.kind}</span>
            <span className="figure">{entry.count.toLocaleString()}</span>
          </Link>
        ))}
      </div>

      <div className="rail-group">
        <div className="rail-label">Adding items</div>
        <Text size="xs" c="dimmed" px="var(--s3)" style={{ lineHeight: 1.5 }}>
          Drop files or a whole folder anywhere on this page. They are written
          to your default storage, then indexed.
        </Text>
      </div>
    </>
  )
}
