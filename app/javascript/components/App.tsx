import { Button, Group, Loader, Menu, UnstyledButton } from '@mantine/core'
import type { Account } from '@masks/client'
import {
  IconDatabase,
  IconLayoutGrid,
  IconLink,
  IconProgressCheck,
  IconRss,
  IconSearch,
  IconSettings,
  IconShieldLock,
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
import { asUrl, type Intent, intentFor, shortly } from '../add'
import { useSession } from '../hooks/useSession'
import { useTitle } from '../hooks/useTitle'
import { tone } from '../kinds'
import { AddButton, AddProvider, useAdd } from './Add'
import { Audit } from './Audit'
import { Catalog } from './Catalog'
import { Cycle } from './Cycle'
import { Face } from './Face'
import { Fallen } from './Fallen'
import { FeedDetail } from './FeedDetail'
import { Feeds } from './Feeds'
import { ItemDetail } from './ItemDetail'
import { Lost } from './Lost'
import { Mark } from './Mark'
import { Merges } from './Merges'
import { Resources } from './Resources'
import { Runs } from './Runs'
import { SayProvider } from './Say'
import { Settings } from './Settings'
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
  { to: '/feeds', label: 'Feeds', icon: IconRss },
  { to: '/resources', label: 'Resources', icon: IconDatabase },
  { to: '/runs', label: 'Runs', icon: IconProgressCheck },
  { to: '/audit', label: 'Audit', icon: IconShieldLock },
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
    <SayProvider>
      <UploadsProvider>
        <AddProvider>
          <Shell
            account={account}
            who={account.nickname ?? account.name ?? account.email ?? 'you'}
            tenant={account.tenant?.name}
            logout={logout}
            logoutEverywhere={logoutEverywhere}
          />
        </AddProvider>
      </UploadsProvider>
    </SayProvider>
  )
}

function Gate({
  unconnected,
  enter,
}: {
  unconnected: boolean
  enter: () => void
}) {
  useTitle('Sign in')

  return (
    <div className="gate">
      <div className="gate-inner">
        <div className="gate-mark">
          <Mark size={92} />
        </div>

        <p className="gate-line">
          <span className="wordmark">uris.to</span>/
          <Cycle words={VERBS} />
        </p>

        <p className="gate-tagline">Yours to keep</p>

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
  account,
  who,
  tenant,
  logout,
  logoutEverywhere,
}: {
  account: Account
  who: string
  tenant?: string | null
  logout: () => void
  logoutEverywhere: () => void
}) {
  const location = useLocation()

  return (
    <div className="shell">
      <header className="shell-head">
        <Link to="/" className="mark-link" aria-label="uris">
          <Mark />
        </Link>

        <Nav />

        <Hunt />

        <AddButton />

        <Kinds />

        <Menu position="bottom-end" width={210}>
          <Menu.Target>
            <UnstyledButton className="face-button" aria-label={who}>
              <Face account={account} />
            </UnstyledButton>
          </Menu.Target>
          <Menu.Dropdown>
            <Menu.Label>
              {who}
              {tenant ? ` · ${tenant}` : ''}
            </Menu.Label>
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

      <main className="shell-main">
        <Fallen key={location.pathname}>
          <Routes>
            <Route path="/" element={<Catalog />} />
            <Route path="/items/:id" element={<ItemDetail />} />
            <Route path="/merges" element={<Merges />} />
            <Route path="/feeds" element={<Feeds />} />
            <Route path="/feeds/:slug" element={<FeedDetail />} />
            <Route path="/resources" element={<Resources />} />
            <Route path="/resources/:id" element={<Resources />} />
            <Route path="/runs" element={<Runs />} />
            <Route path="/audit" element={<Audit />} />
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
            <Route path="*" element={<Lost />} />
          </Routes>
        </Fallen>
      </main>
    </div>
  )
}

function Nav() {
  const location = useLocation()
  const on = (to: string) =>
    to === '/' ? location.pathname === '/' : location.pathname.startsWith(to)
  const here = SECTIONS.find((section) => on(section.to)) ?? SECTIONS[0]

  return (
    <>
      <nav className="head-nav">
        {SECTIONS.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className="head-link"
            aria-current={on(to) ? 'page' : undefined}
          >
            <Icon size={16} stroke={1.6} />
            {label}
          </Link>
        ))}
      </nav>

      <Menu position="bottom-start" width={190}>
        <Menu.Target>
          <Button
            className="head-nav-menu"
            variant="subtle"
            color="gray"
            size="compact-sm"
            leftSection={<here.icon size={16} stroke={1.6} />}
          >
            {here.label}
          </Button>
        </Menu.Target>
        <Menu.Dropdown>
          {SECTIONS.map(({ to, label, icon: Icon }) => (
            <Menu.Item
              key={to}
              component={Link}
              to={to}
              leftSection={<Icon size={16} stroke={1.6} />}
            >
              {label}
            </Menu.Item>
          ))}
        </Menu.Dropdown>
      </Menu>
    </>
  )
}

function Kinds() {
  const location = useLocation()
  const [params] = useSearchParams()
  const { settledAt } = useUploads()
  const { addedAt } = useAdd()
  const { data, refetch } = useQuery(CatalogDocument, {
    kind: null,
    after: null,
    limit: 1,
  })

  useEffect(() => {
    if (settledAt || addedAt) refetch()
  }, [settledAt, addedAt, refetch])

  if (location.pathname !== '/') return null

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
    <Menu position="bottom-end" width={230}>
      <Menu.Target>
        <Button
          variant={kind ? 'light' : 'subtle'}
          color="gray"
          size="compact-sm"
          radius="xl"
          leftSection={
            kind ? (
              <span
                className="dot"
                style={{ '--tone': tone(kind) } as CSSProperties}
              />
            ) : undefined
          }
        >
          {kind ?? 'All kinds'}
        </Button>
      </Menu.Target>
      <Menu.Dropdown>
        <Menu.Item component={Link} to={linkTo(null)}>
          <Group justify="space-between" gap="var(--s4)">
            <span>everything</span>
            <span className="figure">{total.toLocaleString()}</span>
          </Group>
        </Menu.Item>

        {kinds.length > 0 && <Menu.Divider />}

        {kinds.map((entry) => (
          <Menu.Item
            key={entry.kind}
            component={Link}
            to={linkTo(entry.kind === kind ? null : entry.kind)}
            leftSection={
              <span
                className="dot"
                style={{ '--tone': tone(entry.kind) } as CSSProperties}
              />
            }
          >
            <Group justify="space-between" gap="var(--s4)">
              <span>{entry.kind}</span>
              <span className="figure">{entry.count.toLocaleString()}</span>
            </Group>
          </Menu.Item>
        ))}
      </Menu.Dropdown>
    </Menu>
  )
}

const OFFERS: { intent: Intent; what: string; where: string }[] = [
  { intent: 'snapshot', what: 'Keep the page', where: 'as it looks now' },
  { intent: 'fetch', what: 'Keep the file', where: 'at that address' },
]

// The same box searches and adds. Anything with a space in it is a search and
// nothing else; the moment what is typed reads as an address, the two ways of
// keeping it are offered under the bar and Enter takes the likelier one.
function Hunt() {
  const [params, setParams] = useSearchParams()
  const navigate = useNavigate()
  const { keepUrl, busy } = useAdd()
  const term = params.get('q') ?? ''
  const [draft, setDraft] = useState(term)
  const [wanted, setWanted] = useState<Intent | null>(null)
  const [said, setSaid] = useState<string | null>(null)

  useEffect(() => setDraft(term), [term])

  const found = asUrl(draft)
  const intent = wanted ?? (found ? intentFor(found) : 'snapshot')
  const offering = found !== null && said === null

  const search = () => {
    const next = new URLSearchParams(params)

    if (draft.trim()) next.set('q', draft.trim())
    else next.delete('q')

    if (window.location.pathname === '/') setParams(next)
    else navigate(`/?${next.toString()}`)
  }

  const keep = async (taking: Intent) => {
    const outcome = await keepUrl(draft, taking)

    setSaid(
      outcome.ok
        ? `${outcome.added.label} — ${outcome.added.detail}`
        : outcome.refused,
    )

    if (outcome.ok) setDraft('')

    window.setTimeout(() => setSaid(null), 4000)
  }

  return (
    <form
      className="hunt"
      onSubmit={(event) => {
        event.preventDefault()

        if (found) keep(intent)
        else search()
      }}
    >
      {found ? (
        <IconLink size={16} stroke={1.8} color="var(--brass)" />
      ) : (
        <IconSearch size={16} stroke={1.8} color="var(--muted)" />
      )}

      <input
        value={draft}
        onChange={(event) => {
          setDraft(event.currentTarget.value)
          setWanted(null)
          setSaid(null)
        }}
        onKeyDown={(event) => {
          if (!offering) return

          if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault()
            setWanted(intent === 'snapshot' ? 'fetch' : 'snapshot')
          }

          if (event.key === 'Escape') setDraft('')
        }}
        placeholder="Search everything you own, or paste an address"
        aria-label="Search everything you own, or paste an address"
      />

      {term && !found && (
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

      {said && <div className="hunt-drop hunt-said">{said}</div>}

      {offering && (
        <div className="hunt-drop">
          {OFFERS.map((offer) => (
            <button
              key={offer.intent}
              type="button"
              className="hunt-row"
              data-on={intent === offer.intent}
              disabled={busy}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => keep(offer.intent)}
            >
              <span className="hunt-what">{offer.what}</span>
              <span className="hunt-address">{shortly(found)}</span>
              <span className="hunt-where">{offer.where}</span>
            </button>
          ))}
        </div>
      )}
    </form>
  )
}
