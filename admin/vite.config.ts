import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// baca version dari pubspec.yaml biar sinkron
let appVersion = '6.8.1'
try {
  const pubspec = readFileSync(fileURLToPath(new URL('../pubspec.yaml', import.meta.url)), 'utf8')
  appVersion = (pubspec.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m) || [])[1] || appVersion
} catch {}

export default defineConfig({
  plugins: [react()],
  define: { __APP_VERSION__: JSON.stringify(appVersion) },
  server: { host: '0.0.0.0', port: 5174 },
  preview: { port: 4174 }
})
