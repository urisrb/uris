import '@mantine/core/styles.css'
import '../styles/uris.css'

import { MantineProvider } from '@mantine/core'
import { UrisProvider } from '@uris/client/react'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { App } from '../components/App'
import { theme } from '../theme'
import { client } from '../uris'

const root = document.getElementById('root')

if (root) {
  createRoot(root).render(
    <StrictMode>
      <MantineProvider theme={theme} forceColorScheme="dark">
        <UrisProvider client={client}>
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </UrisProvider>
      </MantineProvider>
    </StrictMode>,
  )
}
