import '@mantine/core/styles.css'
import '../styles/things.css'

import { MantineProvider } from '@mantine/core'
import { ThingsProvider } from '@thingies/client/react'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { App } from '../components/App'
import { theme } from '../theme'
import { things } from '../things'

const root = document.getElementById('root')

if (root) {
  createRoot(root).render(
    <StrictMode>
      <MantineProvider theme={theme} forceColorScheme="dark">
        <ThingsProvider client={things}>
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </ThingsProvider>
      </MantineProvider>
    </StrictMode>,
  )
}
