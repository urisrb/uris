import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

const clientPort = Number(process.env.DEV_CLIENT_PORT) || undefined
const allowedHosts = process.env.DEV_ALLOWED_HOSTS?.split(',').filter(Boolean)

export default defineConfig({
  plugins: [react(), RubyPlugin()],
  server: clientPort
    ? {
        allowedHosts,
        ws: { clientPort },
        watch: { usePolling: true, interval: 300 },
      }
    : undefined,
})
