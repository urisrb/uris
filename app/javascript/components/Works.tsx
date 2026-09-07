import {
  IconDatabase,
  IconProgressCheck,
  IconShieldLock,
} from '@tabler/icons-react'
import { Link, Outlet, useLocation } from 'react-router-dom'

export const WORKS = [
  { to: '/resources', label: 'Resources', icon: IconDatabase },
  { to: '/runs', label: 'Runs', icon: IconProgressCheck },
  { to: '/audit', label: 'Audit', icon: IconShieldLock },
]

export function Works() {
  const { pathname } = useLocation()

  return (
    <div className="works">
      <nav className="subnav">
        {WORKS.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className="subnav-link"
            aria-current={pathname.startsWith(to) ? 'page' : undefined}
          >
            <Icon size={16} stroke={1.6} />
            {label}
          </Link>
        ))}
      </nav>

      <Outlet />
    </div>
  )
}
