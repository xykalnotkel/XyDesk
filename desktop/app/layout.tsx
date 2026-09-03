import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'XyDesk',
  description: 'XyDesk Host Desktop — panel host Windows.',
  // Favicon jendela/pratinjau = aset identitas yang sama dengan web & APK.
  icons: { icon: '/logo.png' },
};

export const viewport: Viewport = {
  // #131315 adalah sisa tema lama; shell ini terang (var(--bg) = #fafaf9) dan
  // warna jendela di electron/main.cjs sudah disamakan ke situ.
  themeColor: '#fafaf9',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
