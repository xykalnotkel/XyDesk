// Login Google via OAuth 2.0 redirect flow (OpenID Connect implicit).
//
// Kenapa redirect, bukan popup GIS: popup Google Identity Services sering
// macet di about:blank pada Safari iOS, in-app browser (WA/IG), dan browser
// dengan popup blocker. Redirect flow bebas popup: halaman pindah ke
// accounts.google.com, kembali ke /connect dengan id_token di URL fragment.
// Fragment tidak pernah dikirim ke server — dibaca client, diverifikasi
// signature + audience di Worker (/auth/google), lalu dibuang dari URL.
//
// Client ID WEB dipasok saat build via VITE_GOOGLE_CLIENT_ID (bukan secret).

export const GOOGLE_CLIENT_ID =
  (import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined) ?? '';

const STATE_KEY = 'xydesk.google.state';
const RETURN_PATH = '/connect';

/// Arahkan browser ke halaman login Google. Tidak ada popup.
export function beginGoogleLogin(): void {
  if (!GOOGLE_CLIENT_ID) return;
  const state = crypto.randomUUID();
  const nonce = crypto.randomUUID();
  sessionStorage.setItem(STATE_KEY, state);
  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: `${window.location.origin}${RETURN_PATH}`,
    response_type: 'id_token',
    scope: 'openid email profile',
    state,
    nonce,
    prompt: 'select_account',
  });
  window.location.href = `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
}

/// Baca id_token dari fragment saat kembali dari Google.
/// Mengembalikan null bila tidak ada/tidak valid; URL selalu dibersihkan.
export function consumeGoogleRedirect(): string | null {
  const hash = window.location.hash;
  if (!hash.includes('id_token=')) return null;

  const params = new URLSearchParams(hash.slice(1));
  const idToken = params.get('id_token');
  const state = params.get('state');
  const saved = sessionStorage.getItem(STATE_KEY);
  sessionStorage.removeItem(STATE_KEY);

  // Bersihkan fragment dari URL apa pun hasilnya (jangan tinggalkan token).
  window.history.replaceState({}, '', window.location.pathname);

  if (!idToken || !state || state !== saved) return null;
  return idToken;
}

// ── id_token untuk mode founder berita ──────────────────────────────────
//
// id_token Google juga dipakai sebagai bukti admin di worker berita
// (header `x-admin-google-token`, email == FOUNDER_EMAIL). Token ini
// berumur pendek (±1 jam) dan hanya tersimpan di perangkat pendirinya —
// jauh lebih aman daripada menyimpan ADMIN_TOKEN permanen. Bila kedaluwarsa,
// dibuang otomatis dan founder cukup masuk lagi dengan Google.

const ID_TOKEN_KEY = 'xydesk.web.googleIdToken';

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const body = token.split('.')[1] ?? '';
    const json = atob(body.replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/// Simpan id_token bila masih berlaku (dari `exp` di payload).
export function storeGoogleIdToken(idToken: string): void {
  const payload = decodeJwtPayload(idToken);
  const exp = Number(payload?.exp) || 0;
  if (exp * 1000 > Date.now()) {
    localStorage.setItem(ID_TOKEN_KEY, idToken);
  } else {
    localStorage.removeItem(ID_TOKEN_KEY);
  }
}

/// Ambil id_token yang masih berlaku; kedaluwarsa → buang dan kembalikan null.
export function getStoredGoogleIdToken(): string | null {
  const token = localStorage.getItem(ID_TOKEN_KEY);
  if (!token) return null;
  const payload = decodeJwtPayload(token);
  const exp = Number(payload?.exp) || 0;
  if (exp * 1000 > Date.now()) return token;
  localStorage.removeItem(ID_TOKEN_KEY);
  return null;
}

export function clearStoredGoogleIdToken(): void {
  localStorage.removeItem(ID_TOKEN_KEY);
}
