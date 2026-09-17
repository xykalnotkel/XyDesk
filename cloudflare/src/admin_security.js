import { timingSafeEqual } from './auth.js';

const CREDENTIALS = 'admin:credentials:v1';
const enc = new TextEncoder();
const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const SESSION_TTL = 3600;
const RATE_WINDOW = 15 * 60 * 1000;
export const PASSWORD_ITERATIONS = 100000; // Batas WebCrypto PBKDF2 Workers.
const json = (data, status = 200) => Response.json(data, { status });
const random = n => crypto.getRandomValues(new Uint8Array(n));
const b64 = bytes => btoa(String.fromCharCode(...bytes));
const unb64 = text => Uint8Array.from(atob(text), c => c.charCodeAt(0));
export function base32(bytes) {
  let value = 0, bits = 0, out = '';
  for (const b of bytes) {
    value = (value << 8) | b; bits += 8;
    while (bits >= 5) { bits -= 5; out += alphabet[(value >>> bits) & 31]; }
  }
  if (bits) out += alphabet[(value << (5 - bits)) & 31];
  return out;
}
function decode32(text) {
  let value = 0, bits = 0; const out = [];
  for (const c of text.replace(/=+$/, '')) {
    const n = alphabet.indexOf(c); if (n < 0) throw new Error('invalid-base32');
    value = (value << 5) | n; bits += 5;
    if (bits >= 8) { bits -= 8; out.push((value >>> bits) & 255); }
  }
  return new Uint8Array(out);
}
export async function digest(text) { return b64(new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(text)))); }
export async function passwordHash(password, salt) {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt: unb64(salt), iterations: PASSWORD_ITERATIONS }, key, 256);
  return b64(new Uint8Array(bits));
}
async function passwordVerifier(password, salt, pepper) {
  const hash = await passwordHash(password, salt);
  const key = await crypto.subtle.importKey('raw', enc.encode(pepper), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64(new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode('password-verifier\0' + hash))));
}
export async function totp(secret, counter, digits = 6) {
  const data = new Uint8Array(8); new DataView(data.buffer).setBigUint64(0, BigInt(counter));
  const key = await crypto.subtle.importKey('raw', decode32(secret), { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, data));
  const offset = bytes[bytes.length - 1] & 15;
  const n = new DataView(bytes.buffer).getUint32(offset) & 0x7fffffff;
  return String(n % (10 ** digits)).padStart(digits, '0');
}
async function matchCounter(secret, code, now) {
  if (typeof code !== 'string' || !/^\d{6}$/.test(code)) return null;
  const current = Math.floor(now / 30000);
  for (const step of [0, -1, 1]) if (timingSafeEqual(await totp(secret, current + step), code)) return current + step;
  return null;
}
async function cipherKey(secret) {
  if (!secret || secret.length < 32) throw new Error('admin-key-not-configured');
  return crypto.subtle.importKey('raw', await crypto.subtle.digest('SHA-256', enc.encode('xydesk-admin-mfa\0' + secret)), 'AES-GCM', false, ['encrypt', 'decrypt']);
}
async function seal(value, secret) {
  const iv = random(12), key = await cipherKey(secret);
  return { iv: b64(iv), data: b64(new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(value)))) };
}
async function open(value, secret) {
  const key = await cipherKey(secret);
  return new TextDecoder().decode(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64(value.iv) }, key, unb64(value.data)));
}
const usernameOf = value => typeof value === 'string' ? value.trim().toLowerCase() : '';
const validPassword = value => typeof value === 'string' && value.length >= 14 && value.length <= 128;
const validUsername = value => /^[a-z0-9][a-z0-9._-]{2,31}$/.test(value);
const normalizedRecovery = value => typeof value === 'string' ? value.toUpperCase().replace(/[\s-]/g, '') : '';

// Hanya dipanggil AuthStore setelah header internal diperiksa oleh dispatcher.
export class AdminSecurity {
  constructor(storage, env) { this.storage = storage; this.env = env; }
  async rate(keys, limit, now) {
    const ids = await Promise.all(keys.map(k => digest('rate\0' + this.env.ADMIN_AUTH_KEY + '\0' + k)));
    return this.storage.transaction(async txn => {
      for (const id of ids) {
        const k = 'admin:rate:' + id, old = await txn.get(k);
        const next = old && old.until > now ? old : { count: 0, until: now + RATE_WINDOW };
        if (next.count >= limit) return false;
      }
      for (const id of ids) {
        const k = 'admin:rate:' + id, old = await txn.get(k);
        const next = old && old.until > now ? old : { count: 0, until: now + RATE_WINDOW };
        await txn.put(k, { count: next.count + 1, until: next.until });
      }
      return true;
    });
  }
  async fetch(path, body = {}) {
    const now = Date.now();
    if (path === 'config') return json({ passwordEnabled: !!await this.storage.get(CREDENTIALS), setupAvailable: typeof this.env.ADMIN_AUTH_KEY === 'string' && this.env.ADMIN_AUTH_KEY.length >= 32 });
    if (!this.env.ADMIN_AUTH_KEY || this.env.ADMIN_AUTH_KEY.length < 32) return json({ error: 'admin-key-not-configured' }, 503);
    if (!body || typeof body !== 'object') return json({ error: 'bad-json' }, 400);
    if (path === 'setup/start') {
      if (await this.storage.get(CREDENTIALS)) return json({ error: 'setup-closed' }, 409);
      const username = usernameOf(body.username);
      if (!body.actor || !validUsername(username) || !validPassword(body.password)) return json({ error: 'username-3-32-password-14-128' }, 400);
      if (!await this.rate(['setup:' + body.actor], 5, now)) return json({ error: 'too-many-attempts' }, 429);
      const salt = b64(random(16)), secret = base32(random(20));
      const pending = { username, email: body.actor, salt, passwordHash: await passwordVerifier(body.password, salt, this.env.ADMIN_AUTH_KEY), totp: await seal(secret, this.env.ADMIN_AUTH_KEY), expires: now + 10 * 60 * 1000 };
      await this.storage.put('admin:pending:' + body.actor, pending);
      return json({ secret, expiresAt: pending.expires, otpauthUri: `otpauth://totp/${encodeURIComponent('XyDesk Admin:' + username)}?secret=${secret}&issuer=XyDesk%20Admin&algorithm=SHA1&digits=6&period=30` });
    }
    if (path === 'setup/confirm') {
      if (!body.actor) return json({ error: 'unauthorized' }, 401);
      if (!await this.rate(['confirm:' + body.actor], 5, now)) return json({ error: 'too-many-attempts' }, 429);
      const pendingKey = 'admin:pending:' + body.actor;
      const pending = await this.storage.get(pendingKey);
      if (!pending || pending.expires <= now) return json({ error: 'setup-expired' }, 410);
      const counter = await matchCounter(await open(pending.totp, this.env.ADMIN_AUTH_KEY), body.code, now);
      if (counter === null) return json({ error: 'invalid-authenticator-code' }, 400);
      const recoveryCodes = Array.from({ length: 10 }, () => base32(random(16)));
      const recoveryHashes = await Promise.all(recoveryCodes.map(c => digest('recovery\0' + c)));
      const token = base32(random(32)), sessionKey = 'admin:session:' + await digest(token);
      const result = await this.storage.transaction(async txn => {
        if (await txn.get(CREDENTIALS)) return false;
        const current = await txn.get(pendingKey);
        if (!current || current.expires <= now || current.passwordHash !== pending.passwordHash || current.totp.data !== pending.totp.data) return false;
        const credential = { schema: 1, version: 1, username: pending.username, email: pending.email, salt: pending.salt, passwordHash: pending.passwordHash, iterations: PASSWORD_ITERATIONS, totp: pending.totp, lastCounter: counter, recoveryHashes, createdAt: now };
        await txn.put(CREDENTIALS, credential);
        await txn.put(sessionKey, { email: pending.email, username: pending.username, version: 1, expiresAt: now + SESSION_TTL * 1000 });
        await txn.delete(pendingKey);
        await txn.put(`admin:log:${now}:security:setup`, { action: 'security-setup', at: now, by: pending.email });
        return true;
      });
      if (!result) return json({ error: 'setup-closed-or-changed' }, 409);
      return json({ token, email: pending.email, username: pending.username, setupRequired: false, recoveryCodes });
    }
    if (path === 'login') {
      const username = usernameOf(body.username);
      if (!validUsername(username) || typeof body.password !== 'string' || body.password.length > 128 || typeof body.code !== 'string' || body.code.length > 64) return json({ error: 'invalid-credentials' }, 401);
      if (!await this.rate(['login-ip:' + (body.ip || 'unknown')], 20, now) || !await this.rate(['login-user:' + username], 5, now)) return json({ error: 'too-many-attempts' }, 429);
      const credential = await this.storage.get(CREDENTIALS);
      if (!credential) return json({ error: 'setup-required' }, 409);
      const hash = await passwordVerifier(body.password, credential.salt, this.env.ADMIN_AUTH_KEY);
      if (!timingSafeEqual(username, credential.username) || !timingSafeEqual(hash, credential.passwordHash)) return json({ error: 'invalid-credentials' }, 401);
      let counter = null, recoveryHash = null;
      if (body.recovery === true) {
        recoveryHash = await digest('recovery\0' + normalizedRecovery(body.code));
        if (!credential.recoveryHashes.some(h => timingSafeEqual(h, recoveryHash))) return json({ error: 'invalid-credentials' }, 401);
      } else {
        counter = await matchCounter(await open(credential.totp, this.env.ADMIN_AUTH_KEY), body.code, now);
        if (counter === null || counter <= credential.lastCounter) return json({ error: 'invalid-credentials' }, 401);
      }
      const token = base32(random(32)), sessionKey = 'admin:session:' + await digest(token);
      const success = await this.storage.transaction(async txn => {
        const current = await txn.get(CREDENTIALS);
        if (!current || current.version !== credential.version) return false;
        if (recoveryHash) {
          if (!current.recoveryHashes.includes(recoveryHash)) return false;
          current.recoveryHashes = current.recoveryHashes.filter(h => h !== recoveryHash);
        } else {
          if (counter <= current.lastCounter) return false;
          current.lastCounter = counter;
        }
        await txn.put(CREDENTIALS, current);
        await txn.put(sessionKey, { email: current.email, username: current.username, version: current.version, expiresAt: now + SESSION_TTL * 1000 });
        await txn.put(`admin:log:${now}:security:login`, { action: recoveryHash ? 'security-recovery-login' : 'security-login', at: now, by: current.email });
        return true;
      });
      if (!success) return json({ error: 'invalid-credentials' }, 401);
      return json({ token, email: credential.email, username: credential.username, setupRequired: false });
    }
    if (path === 'session' || path === 'logout') {
      if (typeof body.token !== 'string' || !/^[A-Z2-7]{52}$/.test(body.token)) return json({ error: 'unauthorized' }, 401);
      const key = 'admin:session:' + await digest(body.token);
      if (path === 'logout') { await this.storage.delete(key); return json({ ok: true }); }
      const session = await this.storage.get(key), credential = await this.storage.get(CREDENTIALS);
      if (!session || !credential || session.expiresAt <= now || session.version !== credential.version) {
        if (session) await this.storage.delete(key);
        return json({ error: 'unauthorized' }, 401);
      }
      return json({ email: session.email, username: session.username, setupRequired: false, role: 'admin' });
    }
    return json({ error: 'not-found' }, 404);
  }
}
