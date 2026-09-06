import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Versi dibaca dari pubspec.yaml — sumber yang sama dengan APK dan installer.
// Sebelumnya footer web menulis versi tangan dan tertinggal empat rilis
// ("v2.5.0" saat aplikasi sudah 6.1.0). Satu sumber, satu angka.
const pubspec = readFileSync(
  fileURLToPath(new URL('../pubspec.yaml', import.meta.url)),
  'utf8',
);
const appVersion = (pubspec.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m) ||
  [])[1];
if (!appVersion) {
  throw new Error('vite: gagal membaca version dari pubspec.yaml');
}

// Backend produksi tetap Worker yang sama dengan aplikasi mobile/desktop.
// Saat dev lokal, /api diarahkan ke Worker produksi agar tidak perlu
// menjalankan backend lokal.
export default defineConfig({
  plugins: [react()],
  define: {
    __APP_VERSION__: JSON.stringify(appVersion),
  },
  server: {
    host: '0.0.0.0',
    // Izinkan preview lewat proxy host mana pun saat dev di sandbox/CI.
    allowedHosts: true,
    proxy: {
      '/api': {
        target: 'https://signal.xydesk.my.id',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
  build: {
    target: 'es2020',
    sourcemap: false,
  },
});
