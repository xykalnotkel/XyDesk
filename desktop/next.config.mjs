/** @type {import('next').NextConfig} */
// Static export: renderer disajikan oleh proses utama Electron lewat server
// HTTP lokal (bukan file://) — lihat electron/main.cjs. Output murni statis,
// tanpa SSR/API routes (Next.js dipakai sebagai toolchain UI saja).
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
};

export default nextConfig;
