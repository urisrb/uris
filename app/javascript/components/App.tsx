import {
  AppShell,
  Burger,
  Button,
  Center,
  Group,
  Loader,
  Menu,
  NavLink,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import { useDisclosure } from '@mantine/hooks'
import {
  IconDatabase,
  IconLayoutGrid,
  IconProgressCheck,
} from '@tabler/icons-react'
import { Link, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { useSession } from '../hooks/useSession'
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
  const { account, status, loading, login, logout, logoutEverywhere, connect } =
    useSession()

  if (loading) {
    return (
      <Center h="100vh">
        <Loader />
      </Center>
    )
  }

  if (!account) {
    const unconnected = status?.state === 'handshake_required'

    return (
      <Center h="100vh">
        <Stack align="center" gap="sm">
          <Title order={3}>things</Title>
          <Text c="dimmed" size="sm">
            {unconnected
              ? 'this app has not been connected to the server that signs people in'
              : 'one index across everything you own'}
          </Text>
          <Button mt="md" onClick={unconnected ? connect : login}>
            {unconnected ? 'Connect it' : 'Sign in'}
          </Button>
        </Stack>
      </Center>
    )
  }

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
          <Menu position="bottom-end">
            <Menu.Target>
              <Button variant="subtle" size="compact-sm" ml="auto">
                {account.nickname ?? account.name ?? account.email}
              </Button>
            </Menu.Target>
            <Menu.Dropdown>
              <Menu.Label>{account.tenant?.name}</Menu.Label>
              <Menu.Item onClick={logout}>Sign out</Menu.Item>
              <Menu.Item onClick={logoutEverywhere}>
                Sign out everywhere
              </Menu.Item>
            </Menu.Dropdown>
          </Menu>
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
