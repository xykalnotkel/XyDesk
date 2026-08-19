import { defineConfig } from 'vite';

// UI desktop XyDesk (Tauri WebView2). Tanpa framework berat — vanilla TS,
// karena UI host hanya: identitas, status engine, dan beberapa tombol.
export default defineConfig({
  clearScreen: false,
  server: { port: 1420, strictPort: true },
  build: { target: 'es2021', sourcemap: false },
});
