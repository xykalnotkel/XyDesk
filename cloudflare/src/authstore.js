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
const GUEST_IP_WINDOW = 60 * 60;
const GUEST_IP_MAX_REQUESTS = 20;

// ── Rem klaim device (lihat host/src/pairguard.rs untuk model ancaman) ────
//
// pairguard.rs melindungi percobaan pairing yang sampai ke binary host. Jalur
// /host-token TIDAK melewatinya sama sekali: penyerang menukar {device_id,
// claim} langsung di edge dan tidak pernah menyentuh PC korban. Device ID cuma
// 9 digit dan disiarkan ke semua client lewat pesan `devices`, sedangkan claim
// boleh sependek 6 karakter dan sering dipilih manusia. Tanpa rem di sini,
// laju tebakan hanya dibatasi kecepatan jaringan — dan hadiahnya token
// role=host yang sah untuk perangkat orang lain.
//
// Dua lapis, sengaja meniru pembagian di pairguard:
//   1. Per device — menutup penyerang yang berganti-ganti IP (botnet/proxy).
//      Ini lapis yang benar-benar penting, karena target serangannya satu
//      device tertentu.
//   2. Per IP — menutup penyerang yang menyapu banyak device dari satu tempat.
// Klaim yang benar menghapus catatan kegagalan device (lihat pairguard: user
// sah yang salah ketik tidak dihukum berkepanjangan).
const CLAIM_DEVICE_MAX_FAILURES = 5;
const CLAIM_DEVICE_LOCKOUT = 15 * 60;
const CLAIM_IP_WINDOW = 10 * 60;
const CLAIM_IP_MAX_REQUESTS = 30;

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
    if (path === '/auth/guest' && request.method === 'POST') {
      return this.guest(request);
    }
    if (path === '/auth/authorize-host' && request.method === 'POST') {
      return this.authorizeHost(request);
    }
    if (path === '/auth/claim-device' && request.method === 'POST') {
      return this.claimDevice(request);
    }
    if (path === '/auth/me' && request.method === 'GET') {
      return this.me(request);
    }
    if (path === '/auth/profile' && request.method === 'POST') {
      return this.updateProfile(request);
    }
    if (path === '/auth/delete' && request.method === 'POST') {
      return this.deleteAccount(request);
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
    return this.consumeRateLimit(
      request,
      now,
      'otp',
      OTP_IP_WINDOW,
      OTP_IP_MAX_REQUESTS,
    );
  }

  async consumeRateLimit(request, now, purpose, windowSeconds, maxRequests) {
    const ip = request.headers.get('CF-Connecting-IP');
    // Header ini selalu diisi Cloudflare pada produksi. Dev lokal tidak dipukul
    // oleh bucket global palsu bernama "unknown".
    if (!ip) return { ok: true, retryIn: 0 };

    const keyHash = await hashOtp(this.secret(), `rate-${purpose}`, ip);
    const key = `rate:${purpose}:${keyHash}`;
    let bucket = await this.ctx.storage.get(key);
    if (!bucket || now - bucket.started_at >= windowSeconds) {
      bucket = { started_at: now, count: 0 };
    }
    if (bucket.count >= maxRequests) {
      return {
        ok: false,
        retryIn: Math.max(1, windowSeconds - (now - bucket.started_at)),
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

  async authorizeHost(request) {
    if (request.headers.get('X-XyDesk-Internal') !== this.env.XYDESK_SECRET) {
      return json({ error: 'forbidden' }, 403);
    }
    let owner, device_id, claim;
    try {
      ({ owner, device_id, claim } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    if (
      typeof owner !== 'string' ||
      !owner ||
      typeof device_id !== 'string' ||
      !/^\d{9}$/.test(device_id) ||
      typeof claim !== 'string' ||
      claim.length < 6 ||
      claim.length > 128
    ) {
      return json({ error: 'invalid-host-claim' }, 400);
    }

    const key = `device:${device_id}`;
    const claimHash = await hashOtp(this.secret(), `device:${device_id}`, claim);
    const existing = await this.ctx.storage.get(key);
    if (existing) {
      if (existing.owner !== owner) {
        return json({ error: 'device-owned-by-another-account' }, 403);
      }
      if (!timingSafeEqual(existing.claim_hash, claimHash)) {
        existing.claim_hash = claimHash;
        existing.rotated_at = Math.floor(Date.now() / 1000);
        await this.ctx.storage.put(key, existing);
      }
      return json({ ok: true, claimed: false }, 200);
    }

    await this.ctx.storage.put(key, {
      owner,
      claim_hash: claimHash,
      claimed_at: Math.floor(Date.now() / 1000),
    });
    return json({ ok: true, claimed: true }, 200);
  }

  /// Klaim device tanpa akun (trust-on-first-use) untuk host desktop.
  ///
  /// Pertama kali: pasangan device+claim dikunci (owner = 'tofu').
  /// Selanjutnya: claim wajib cocok dengan hash tersimpan. Device yang
  /// diikat akun via authorize-host memakai jalur verifikasi yang sama —
  /// claim (password pairing) tetap kuncinya.
  async claimDevice(request) {
    if (request.headers.get('X-XyDesk-Internal') !== this.env.XYDESK_SECRET) {
      return json({ error: 'forbidden' }, 403);
    }
    let device_id, claim;
    try {
      ({ device_id, claim } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    if (
      typeof device_id !== 'string' ||
      !/^\d{9}$/.test(device_id) ||
      typeof claim !== 'string' ||
      claim.length < 6 ||
      claim.length > 128
    ) {
      return json({ error: 'invalid-claim' }, 400);
    }

    const now = Math.floor(Date.now() / 1000);

    // Rem per IP dulu (murah, satu get) sebelum kerja kripto apa pun.
    const ipLimit = await this.consumeRateLimit(
      request,
      now,
      'claim',
      CLAIM_IP_WINDOW,
      CLAIM_IP_MAX_REQUESTS,
    );
    if (!ipLimit.ok) {
      return json({ error: 'rate-limited', retry_in: ipLimit.retryIn }, 429);
    }

    // Rem per device: penyerang boleh berganti IP sesukanya, tapi jatah
    // tebakan menempel pada device yang diserang.
    const lock = await this.claimLockState(device_id, now);
    if (lock.locked) {
      return json({ error: 'device-locked', retry_in: lock.retryIn }, 429);
    }

    const key = `device:${device_id}`;
    const claimHash = await hashOtp(this.secret(), `device:${device_id}`, claim);
    const existing = await this.ctx.storage.get(key);
    if (existing) {
      if (!timingSafeEqual(existing.claim_hash, claimHash)) {
        const state = await this.recordClaimFailure(device_id, now);
        if (state.locked) {
          return json({ error: 'device-locked', retry_in: state.retryIn }, 429);
        }
        return json({ error: 'claim-mismatch' }, 403);
      }
      await this.ctx.storage.delete(`claimfail:${device_id}`);
      return json({ ok: true, claimed: false }, 200);
    }

    await this.ctx.storage.put(key, {
      owner: 'tofu',
      claim_hash: claimHash,
      claimed_at: now,
    });
    await this.ctx.storage.delete(`claimfail:${device_id}`);
    return json({ ok: true, claimed: true }, 200);
  }

  /// Status kunci klaim untuk satu device. Kunci kedaluwarsa sendiri; tidak
  /// ada pembersih terjadwal supaya DO tetap sederhana.
  async claimLockState(deviceId, now) {
    const state = await this.ctx.storage.get(`claimfail:${deviceId}`);
    if (!state || !state.locked_until) return { locked: false, retryIn: 0 };
    if (state.locked_until <= now) {
      await this.ctx.storage.delete(`claimfail:${deviceId}`);
      return { locked: false, retryIn: 0 };
    }
    return { locked: true, retryIn: state.locked_until - now };
  }

  /// Catat satu tebakan salah. Setelah CLAIM_DEVICE_MAX_FAILURES kegagalan,
  /// device dikunci CLAIM_DEVICE_LOCKOUT detik.
  async recordClaimFailure(deviceId, now) {
    const key = `claimfail:${deviceId}`;
    const state = (await this.ctx.storage.get(key)) || { count: 0, locked_until: 0 };
    state.count += 1;
    if (state.count >= CLAIM_DEVICE_MAX_FAILURES) {
      state.count = 0;
      state.locked_until = now + CLAIM_DEVICE_LOCKOUT;
      await this.ctx.storage.put(key, state);
      return { locked: true, retryIn: CLAIM_DEVICE_LOCKOUT };
    }
    await this.ctx.storage.put(key, state);
    return { locked: false, retryIn: 0 };
  }

  async guest(request) {
    // Sesi tamu hanya memberi hak sebagai client signaling selama dua jam.
    // Tidak disimpan, tidak punya email, dan tidak dapat mengklaim host.
    const now = Math.floor(Date.now() / 1000);
    const rateLimit = await this.consumeRateLimit(
      request,
      now,
      'guest',
      GUEST_IP_WINDOW,
      GUEST_IP_MAX_REQUESTS,
    );
    if (!rateLimit.ok) {
      return json({ error: 'rate-limited', retry_in: rateLimit.retryIn }, 429);
    }
    const id = crypto.randomUUID();
    const token = await signJwt(
      { sub: `guest:${id}`, guest: true },
      this.secret(),
      2 * 60 * 60,
    );
    return json({ token, guest: true }, 200);
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

  /// Ganti nama tampilan. Nama 2-60 karakter, tanpa kontrol karakter.
  async updateProfile(request) {
    const user = await this.userFromRequest(request);
    if (!user) return json({ error: 'unauthorized' }, 401);

    let name;
    try {
      ({ name } = await request.json());
    } catch {
      return json({ error: 'bad-json' }, 400);
    }
    name = String(name || '').trim().replace(/[\u0000-\u001f\u007f]/g, '');
    if (name.length < 2 || name.length > 60) {
      return json({ error: 'invalid-name' }, 400);
    }

    user.name = name;
    await this.ctx.storage.put(`user:${user.email}`, user);
    return json({ user: this.publicUser(user) }, 200);
  }

  /// Hapus akun permanen. JWT lama otomatis tidak berguna karena record
  /// user hilang (me() akan menjawab 404).
  async deleteAccount(request) {
    const user = await this.userFromRequest(request);
    if (!user) return json({ error: 'unauthorized' }, 401);
    await this.ctx.storage.delete(`user:${user.email}`);
    await this.ctx.storage.delete(`otp:${user.email}`);
    return json({ ok: true }, 200);
  }

  /// Resolusi user dari Bearer JWT; null bila token tidak sah.
  async userFromRequest(request) {
    const auth = request.headers.get('Authorization') || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const payload = await verifyJwt(token, this.secret());
    if (!payload) return null;
    const user = await this.ctx.storage.get(`user:${payload.email}`);
    // sub harus cocok — token lama dari akun terhapus/dibuat ulang ditolak.
    if (!user || user.id !== payload.sub) return null;
    return user;
  }
}
