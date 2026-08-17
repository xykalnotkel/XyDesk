// Google Identity Services (GIS) — tombol "Sign in with Google" resmi.
//
// Client ID WEB dipasok saat build via VITE_GOOGLE_CLIENT_ID (bukan secret;
// audience diverifikasi server-side di Worker). Tanpa client id, tombol
// Google disembunyikan dan login email OTP tetap jalan.

export const GOOGLE_CLIENT_ID =
  (import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined) ?? '';

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize(config: {
            client_id: string;
            callback: (response: { credential: string }) => void;
            ux_mode?: string;
          }): void;
          renderButton(
            parent: HTMLElement,
            options: {
              theme?: string;
              size?: string;
              text?: string;
              shape?: string;
              width?: number;
              logo_alignment?: string;
            },
          ): void;
        };
      };
    };
  }
}

let loader: Promise<void> | null = null;

/// Muat script GIS sekali; resolve saat window.google siap.
export function loadGis(): Promise<void> {
  if (!GOOGLE_CLIENT_ID) return Promise.reject(new Error('no-client-id'));
  if (loader) return loader;
  loader = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = 'https://accounts.google.com/gsi/client';
    s.async = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('gis-load-failed'));
    document.head.appendChild(s);
  });
  return loader;
}

/// Render tombol Google resmi ke [el]; [onCredential] menerima ID token.
export async function renderGoogleButton(
  el: HTMLElement,
  onCredential: (idToken: string) => void,
): Promise<void> {
  await loadGis();
  window.google!.accounts.id.initialize({
    client_id: GOOGLE_CLIENT_ID,
    callback: (r) => onCredential(r.credential),
  });
  window.google!.accounts.id.renderButton(el, {
    theme: 'filled_black',
    size: 'large',
    text: 'continue_with',
    shape: 'pill',
    width: 320,
  });
}
