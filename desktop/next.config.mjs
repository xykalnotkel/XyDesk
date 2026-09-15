/** @type {import('next').NextConfig} */
// Static export: renderer dimuat oleh WebView Tauri dari output statis.
// Tidak ada server Node atau runtime desktop JavaScript di bundle.
// tanpa SSR/API routes (Next.js dipakai sebagai toolchain UI saja).
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
};

export default nextConfig;
