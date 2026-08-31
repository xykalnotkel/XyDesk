import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'XyDesk',
  description: 'XyDesk Host Desktop — panel host Windows.',
};

export const viewport: Viewport = {
  themeColor: '#131315',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
