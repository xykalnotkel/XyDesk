import { signJwt, verifyJwt } from './auth.js';
export const SESSION_CHECK_MS = 15_000;

export function validPrincipal(p) {
  if (!p || typeof p.sub !== 'string' || !p.sub || !Number.isSafeInteger(p.expiresAt) || p.expiresAt <= Math.floor(Date.now()/1000)) return false;
  return p.guest === true ? p.sub.startsWith('guest:') && p.sub.length > 6
    : p.guest === false && Number.isSafeInteger(p.ver) && p.ver >= 0;
}
export async function signBoundTicket(id, principal, secret) {
  if (!validPrincipal(principal)) throw Error('invalid-principal');
  return 'v2.' + await signJwt({aud:'xydesk-signal',role:'client',deviceId:id,principal}, secret, 300);
}
export async function readBoundTicket(token, id, role, secret) {
  if (!token.startsWith('v2.') || role !== 'client') return null;
  const p = await verifyJwt(token.slice(3), secret);
  return p?.aud === 'xydesk-signal' && p.role === 'client' && p.deviceId === id && validPrincipal(p.principal) ? p.principal : null;
}
// An authenticated internal caller supplies the signed/attached principal,
// never an arbitrary browser header. Failure to reach AuthStore is not approval.
export async function checkPrincipal(env, principal) {
  if (!validPrincipal(principal)) return false;
  // Guests have no mutable account record; their signed expiry is the limit.
  if (principal.guest) return true;
  const store = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'));
  const r = await store.fetch(new Request('https://internal/auth/check-principal', {
    method:'POST', headers:{'X-XyDesk-Internal':env.XYDESK_SECRET,'content-type':'application/json'},
    body:JSON.stringify(principal), signal:AbortSignal.timeout(5000),
  }));
  if (r.status >= 500) throw Error('authorization-unavailable');
  return r.status === 200;
}
