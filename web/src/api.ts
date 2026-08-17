// Klien API XyDesk — bicara ke Worker yang sama dengan aplikasi
// mobile/desktop (auth OTP/Google, signal-token, TURN, WebSocket signaling).
//
// Di produksi frontend dan backend berbeda origin, jadi semua panggilan
// memakai BASE absolut. Saat dev, Vite mem-proxy /api ke Worker produksi.

const PROD_BASE = 'https://signal.xystudio.my.id';
export const API_BASE = import.meta.env.DEV ? '/api' : PROD_BASE;
export const WS_URL = import.meta.env.DEV
  ? `wss://${new URL(PROD_BASE).host}/ws`
  : `${PROD_BASE.replace('https://', 'wss://')}/ws`;

export interface UserProfile {
  id?: string;
  email: string;
  name?: string | null;
  picture?: string | null;
}

export interface AuthSession {
  token: string;
  user?: UserProfile;
}

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new ApiError(
      res.status,
      (data as { error?: string }).error ?? 'unknown',
      (data as { message?: string }).message ?? 'Permintaan gagal.',
    );
  }
  return data as T;
}

export function requestOtp(email: string) {
  return post<{ expires_in: number; resend_in: number }>(
    '/auth/request-otp',
    { email },
  );
}

export function verifyOtp(email: string, otp: string) {
  return post<AuthSession>('/auth/verify-otp', { email, otp });
}

/// Login dengan Google ID token (dari Google Identity Services di browser).
export function signInWithGoogle(idToken: string) {
  return post<AuthSession>('/auth/google', { id_token: idToken });
}

export async function me(token: string) {
  const res = await fetch(`${API_BASE}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new ApiError(res.status, 'unauthorized', 'Sesi berakhir.');
  return (await res.json()) as { user: UserProfile };
}

/// Tukar JWT sesi menjadi token signaling 5 menit untuk deviceId ini.
export async function signalToken(token: string, deviceId: string) {
  const res = await fetch(
    `${API_BASE}/signal-token?id=${encodeURIComponent(deviceId)}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!res.ok) {
    throw new ApiError(res.status, 'signal-token', 'Gagal mendapat izin signaling.');
  }
  return (await res.text()).trim();
}

/// Kredensial TURN ber-TTL; null bila belum dikonfigurasi (cukup STUN).
export async function turnIce(
  deviceId: string,
  token: string,
): Promise<RTCIceServer | null> {
  try {
    const res = await fetch(
      `${API_BASE}/turn-ice?id=${encodeURIComponent(deviceId)}&token=${encodeURIComponent(token)}`,
    );
    if (!res.ok) return null;
    const body = (await res.json()) as { iceServers?: RTCIceServer[] };
    return body.iceServers?.[0] ?? null;
  } catch {
    return null;
  }
}
