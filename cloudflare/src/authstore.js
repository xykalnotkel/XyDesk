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
import { otpEmailHtml, otpEmailText } from './email_otp.js';

const { OTP_TTL, OTP_RESEND_COOLDOWN, OTP_MAX_ATTEMPTS } = authConstants;
const OTP_IP_WINDOW = 10 * 60;
const OTP_IP_MAX_REQUESTS = 8;

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });

function normalizeName(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') return null;
  const name = value.trim().replace(/\s+/g, ' ');
  if (name.length < 2 || name.length > 80 || /[\u0000-\u001f\u007f]/.test(name)) {
    return null;
  }
  return name;
}

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

    if (!this.secret()) {
      console.error('[auth] AUTH_SECRET/XYDESK_SECRET belum dikonfigurasi');
      return json({ error: 'auth-not-configured' }, 503);
    }

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
    let email, name;
    try {
      ({ email, name } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    if (!validateEmail(email)) return json({ error: 'invalid-email' }, 400);
    email = email.toLowerCase();
    const pendingName = normalizeName(name);
    if (name !== undefined && !pendingName) {
      return json({ error: 'invalid-name' }, 400);
    }

    const now = Math.floor(Date.now() / 1000);
    const rateLimit = await this.consumeOtpRateLimit(request, now);
    if (!rateLimit.ok) {
      return json({ error: 'rate-limited', retry_in: rateLimit.retryIn }, 429);
    }

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
      pending_name: pendingName,
    });

    const body = { ok: true, expires_in: OTP_TTL, resend_in: OTP_RESEND_COOLDOWN };
    if (this.env.XYDESK_DEV === 'true' || this.env.DEV === 'true') body.dev_otp = otp;

    // Kirim OTP via email. Produksi tidak boleh mengaku berhasil bila Resend
    // belum dikonfigurasi/gagal, karena pengguna akan menunggu kode yang tak ada.
    const delivery = await this.sendOtpEmail(email, otp);
    if (!delivery.ok) {
      await this.ctx.storage.delete(`otp:${email}`);
      return json({ error: delivery.error }, delivery.status);
    }

    return json(body, 200);
  }

  // Batas per alamat jaringan mencegah endpoint OTP dipakai sebagai alat bom
  // email. Alamat tidak disimpan mentah; key storage memakai hash ber-salt.
  async consumeOtpRateLimit(request, now) {
    const ip = request.headers.get('CF-Connecting-IP');
    // Header ini selalu diisi Cloudflare pada produksi. Dev lokal tidak dipukul
    // oleh bucket global palsu bernama "unknown".
    if (!ip) return { ok: true, retryIn: 0 };

    const keyHash = await hashOtp(this.secret(), 'rate-limit', ip);
    const key = `rate:otp:${keyHash}`;
    let bucket = await this.ctx.storage.get(key);
    if (!bucket || now - bucket.started_at >= OTP_IP_WINDOW) {
      bucket = { started_at: now, count: 0 };
    }
    if (bucket.count >= OTP_IP_MAX_REQUESTS) {
      return {
        ok: false,
        retryIn: Math.max(1, OTP_IP_WINDOW - (now - bucket.started_at)),
      };
    }

    bucket.count += 1;
    await this.ctx.storage.put(key, bucket);
    return { ok: true, retryIn: 0 };
  }

  // Kirim email OTP lewat Resend (gratis 3.000 email/bln, tanpa kartu).
  // Butuh secret RESEND_API_KEY; RESEND_FROM opsional (default onboarding@resend.dev).
  async sendOtpEmail(email, otp) {
    if (!this.env.RESEND_API_KEY) {
      if (this.env.XYDESK_DEV === 'true' || this.env.DEV === 'true') {
        console.log(`[auth] (dev) OTP ${email}: ${otp}`);
        return { ok: true };
      }
      console.error('[auth] RESEND_API_KEY belum dikonfigurasi');
      return { ok: false, status: 503, error: 'email-not-configured' };
    }
    const from = this.env.RESEND_FROM || 'XyDesk <onboarding@resend.dev>';
    const validMinutes = Math.round(OTP_TTL / 60);
    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [email],
          subject: `${otp} — kode verifikasi XyDesk`,
          html: otpEmailHtml({ otp, validMinutes }),
          text: otpEmailText({ otp, validMinutes }),
        }),
      });
      if (!res.ok) {
        console.error(`[auth] gagal kirim email: ${res.status}`);
        return { ok: false, status: 502, error: 'email-send-failed' };
      }
      return { ok: true };
    } catch (e) {
      console.error(`[auth] error kirim email: ${e}`);
      return { ok: false, status: 502, error: 'email-send-failed' };
    }
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
      user = {
        id: crypto.randomUUID(),
        email,
        name: row.pending_name || null,
        created_at: now,
      };
      await this.ctx.storage.put(`user:${email}`, user);
    } else if (!user.name && row.pending_name) {
      // Nama hanya diterapkan setelah OTP benar; request tanpa kepemilikan
      // email tidak dapat mengubah profil akun yang sudah ada.
      user.name = row.pending_name;
      await this.ctx.storage.put(`user:${email}`, user);
    }

    const token = await signJwt({ sub: user.id, email: user.email }, this.secret());
    return json({ token, user: this.publicUser(user) }, 200);
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
      user = {
        id: crypto.randomUUID(),
        email,
        name: r.name || null,
        picture: r.picture || null,
        google_sub: r.sub,
        created_at: now,
      };
      await this.ctx.storage.put(`user:${email}`, user);
    } else {
      if (user.google_sub && user.google_sub !== r.sub) {
        return json({ error: 'identity-conflict' }, 409);
      }
      let changed = false;
      if (!user.google_sub) {
        user.google_sub = r.sub;
        changed = true;
      }
      if (r.name && !user.name) {
        user.name = r.name;
        changed = true;
      }
      // Foto profil Google boleh berubah; selalu segarkan bila berbeda.
      if (r.picture && user.picture !== r.picture) {
        user.picture = r.picture;
        changed = true;
      }
      if (changed) await this.ctx.storage.put(`user:${email}`, user);
    }

    const token = await signJwt({ sub: user.id, email: user.email }, this.secret());
    return json({ token, user: this.publicUser(user) }, 200);
  }

  async me(request) {
    const auth = request.headers.get('Authorization') || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const payload = await verifyJwt(token, this.secret());
    if (!payload) return json({ error: 'unauthorized' }, 401);
    const user = await this.ctx.storage.get(`user:${payload.email}`);
    if (!user) return json({ error: 'user-not-found' }, 404);
    return json({ user: this.publicUser(user) }, 200);
  }

  /// Profil standar yang boleh keluar dari API: id, email, name, picture.
  publicUser(user) {
    return {
      id: user.id,
      email: user.email,
      name: user.name || null,
      picture: user.picture || null,
    };
  }
}
