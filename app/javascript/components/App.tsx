import { AppShell, Burger, Group, NavLink, Text, Title } from '@mantine/core'
import { useDisclosure } from '@mantine/hooks'
import {
  IconDatabase,
  IconLayoutGrid,
  IconProgressCheck,
} from '@tabler/icons-react'
import { Link, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { Catalog } from './Catalog'
import { Resources } from './Resources'
import { Runs } from './Runs'
import { ThingDetail } from './ThingDetail'

const SECTIONS = [
  { to: '/', label: 'Catalog', icon: IconLayoutGrid },
  { to: '/resources', label: 'Resources', icon: IconDatabase },
  { to: '/runs', label: 'Runs', icon: IconProgressCheck },
]

export function App() {
  const [opened, { toggle, close }] = useDisclosure()
  const location = useLocation()
  const navigate = useNavigate()

  return (
    <AppShell
      header={{ height: 56 }}
      navbar={{ width: 220, breakpoint: 'sm', collapsed: { mobile: !opened } }}
      padding="lg"
    >
      <AppShell.Header>
        <Group h="100%" px="md" gap="sm">
          <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
          <Title
            order={4}
            style={{ cursor: 'pointer' }}
            onClick={() => navigate('/')}
          >
            things
          </Title>
          <Text c="dimmed" size="sm" visibleFrom="sm">
            one index across everything you own
          </Text>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p="xs">
        {SECTIONS.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            component={Link}
            to={to}
            label={label}
            onClick={close}
            leftSection={<Icon size={18} stroke={1.5} />}
            active={
              to === '/'
                ? location.pathname === '/'
                : location.pathname.startsWith(to)
            }
          />
        ))}
      </AppShell.Navbar>

      <AppShell.Main>
        <Routes>
          <Route path="/" element={<Catalog />} />
          <Route path="/things/:id" element={<ThingDetail />} />
          <Route path="/resources" element={<Resources />} />
          <Route path="/runs" element={<Runs />} />
        </Routes>
      </AppShell.Main>
    </AppShell>
  )
}
