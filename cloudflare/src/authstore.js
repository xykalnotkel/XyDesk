// XyDesk AuthStore — Durable Object yang menyimpan user & OTP (KV storage)
// dan menjalankan alur auth (request-otp, verify-otp, google, me).
//
// Dipakai sebagai ganti D1 agar tidak butuh izin D1 pada API token — cukup
// izin Workers (yang sudah ada). Data disimpan di storage DO (persisten).
// Skala besar kelak bisa pindah ke D1 tanpa mengubah protokol HTTP.

import {
  signJwt, verifyJwt, validateEmail, generateOtp, hashOtp, timingSafeEqual,
  verifyGoogleIdToken, authConstants,
} from './auth.js';

const { OTP_TTL, OTP_RESEND_COOLDOWN, OTP_MAX_ATTEMPTS } = authConstants;

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });

export class AuthStore {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  secret() {
    return this.env.AUTH_SECRET || this.env.XYDESK_SECRET;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/auth/request-otp' && request.method === 'POST') {
      return this.requestOtp(request);
    }
    if (path === '/auth/verify-otp' && request.method === 'POST') {
      return this.verifyOtp(request);
    }
    if (path === '/auth/google' && request.method === 'POST') {
      return this.google(request);
    }
    if (path === '/auth/me' && request.method === 'GET') {
      return this.me(request);
    }
    return json({ error: 'not-found' }, 404);
  }

  async requestOtp(request) {
    let email;
    try {
      ({ email } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    if (!validateEmail(email)) return json({ error: 'invalid-email' }, 400);
    email = email.toLowerCase();

    const now = Math.floor(Date.now() / 1000);
    const existing = await this.ctx.storage.get(`otp:${email}`);
    if (existing && now - existing.created_at < OTP_RESEND_COOLDOWN) {
      return json({ error: 'cooldown', resend_in: OTP_RESEND_COOLDOWN - (now - existing.created_at) }, 429);
    }

    const otp = generateOtp();
    const hash = await hashOtp(this.secret(), email, otp);
    await this.ctx.storage.put(`otp:${email}`, {
      hash,
      expires_at: now + OTP_TTL,
      attempts: 0,
      created_at: now,
    });

    const body = { ok: true, expires_in: OTP_TTL, resend_in: OTP_RESEND_COOLDOWN };
    if (this.env.XYDESK_DEV === 'true' || this.env.DEV === 'true') body.dev_otp = otp;
    console.log(`[auth] OTP untuk ${email}`);
    return json(body, 200);
  }

  async verifyOtp(request) {
    let email, otp;
    try {
      ({ email, otp } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    if (!validateEmail(email) || !/^\d{6}$/.test(String(otp || ''))) {
      return json({ error: 'invalid-input' }, 400);
    }
    email = email.toLowerCase();
    const now = Math.floor(Date.now() / 1000);

    const row = await this.ctx.storage.get(`otp:${email}`);
    if (!row || now > row.expires_at) return json({ error: 'otp-expired' }, 401);
    if (row.attempts >= OTP_MAX_ATTEMPTS) return json({ error: 'too-many-attempts' }, 429);

    const expect = await hashOtp(this.secret(), email, otp);
    if (!timingSafeEqual(expect, row.hash)) {
      row.attempts += 1;
      await this.ctx.storage.put(`otp:${email}`, row);
      return json({ error: 'wrong-otp' }, 401);
    }

    await this.ctx.storage.delete(`otp:${email}`); // sekali pakai

    let user = await this.ctx.storage.get(`user:${email}`);
    if (!user) {
      user = { id: crypto.randomUUID(), email, created_at: now };
      await this.ctx.storage.put(`user:${email}`, user);
    }

    const token = await signJwt({ sub: user.id, email: user.email }, this.secret());
    return json({ token, user: { id: user.id, email: user.email } }, 200);
  }

  async google(request) {
    let id_token;
    try {
      ({ id_token } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    const r = await verifyGoogleIdToken(this.env, id_token);
    if (!r.ok) return json({ error: r.error }, r.status);

    const email = r.email;
    const now = Math.floor(Date.now() / 1000);
    let user = await this.ctx.storage.get(`user:${email}`);
    if (!user) {
      user = { id: crypto.randomUUID(), email, name: r.name || null, created_at: now };
      await this.ctx.storage.put(`user:${email}`, user);
    } else if (r.name && !user.name) {
      user.name = r.name;
      await this.ctx.storage.put(`user:${email}`, user);
    }

    const token = await signJwt({ sub: user.id, email: user.email }, this.secret());
    return json({ token, user: { id: user.id, email: user.email, name: user.name } }, 200);
  }

  async me(request) {
    const auth = request.headers.get('Authorization') || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const payload = await verifyJwt(token, this.secret());
    if (!payload) return json({ error: 'unauthorized' }, 401);
    const user = await this.ctx.storage.get(`user:${payload.email}`);
    if (!user) return json({ error: 'user-not-found' }, 404);
    return json({ user: { id: user.id, email: user.email, name: user.name } }, 200);
  }
}
