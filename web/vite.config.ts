import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Backend produksi tetap Worker yang sama dengan aplikasi mobile/desktop.
// Saat dev lokal, /api diarahkan ke Worker produksi agar tidak perlu
// menjalankan backend lokal.
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    // Izinkan preview lewat proxy host mana pun saat dev di sandbox/CI.
    allowedHosts: true,
    proxy: {
      '/api': {
        target: 'https://signal.xystudio.my.id',
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
