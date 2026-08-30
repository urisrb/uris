import '@mantine/core/styles.css'

import { createTheme, MantineProvider } from '@mantine/core'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { App } from '../components/App'

const theme = createTheme({
  primaryColor: 'dark',
  defaultRadius: 'md',
  fontFamily:
    'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Helvetica, Arial, sans-serif',
  fontFamilyMonospace:
    'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
})

const root = document.getElementById('root')

if (root) {
  createRoot(root).render(
    <StrictMode>
      <MantineProvider theme={theme} defaultColorScheme="auto">
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </MantineProvider>
    </StrictMode>,
  )
}
