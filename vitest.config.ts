import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['app/javascript/**/*.test.ts'],
    environment: 'node',
  },
})
