// Uji end-to-end auth (OTP email + JWT + Google) melawan wrangler dev.
// Jalankan: npm run dev (terminal lain), lalu: npm run test:auth
const BASE = process.env.XYDESK_BASE || 'http://127.0.0.1:8787';

let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.error(`  ✗ ${name}\n    ${e.message}`);
  }
}

async function post(path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json().catch(() => ({})) };
}

async function get(path, headers = {}) {
  const res = await fetch(`${BASE}${path}`, { headers });
  return { status: res.status, body: await res.json().catch(() => ({})) };
}

// Minta OTP → kembalikan dev_otp (hanya ada di mode dev).
async function requestOtpFor(email) {
  const r = await post('/auth/request-otp', { email });
  if (r.status !== 200 || !r.body.dev_otp) {
    throw new Error(`gagal minta OTP: ${r.status} ${JSON.stringify(r.body)}`);
  }
  return r.body.dev_otp;
}

const uniq = (tag) => `${tag}-${Date.now()}@xydesk.test`;

async function main() {
  console.log('XyDesk auth — uji end-to-end\n');

  await test('request-otp: email tak valid -> 400', async () => {
    const r = await post('/auth/request-otp', { email: 'bukan-email' });
    if (r.status !== 400 || r.body.error !== 'invalid-email') throw new Error(`ingin 400, dapat ${r.status}`);
  });

  await test('request-otp: email valid -> 200 + dev_otp', async () => {
    const r = await post('/auth/request-otp', { email: uniq('a') });
    if (r.status !== 200 || !r.body.dev_otp || !/^\d{6}$/.test(r.body.dev_otp)) {
      throw new Error(`ingin dev_otp 6 digit, dapat ${JSON.stringify(r.body)}`);
    }
  });

  await test('request-otp: kirim ulang cepat -> 429 cooldown', async () => {
    const email = uniq('cd');
    await post('/auth/request-otp', { email });
    const r = await post('/auth/request-otp', { email });
    if (r.status !== 429 || r.body.error !== 'cooldown') throw new Error(`ingin 429, dapat ${r.status}`);
  });

  await test('verify-otp: OTP salah -> 401', async () => {
    const email = uniq('w');
    await requestOtpFor(email);
    const r = await post('/auth/verify-otp', { email, otp: '000000' });
    // 000000 bisa saja kebetulan benar; bila benar, artinya OTP memang 000000
    // (probabilitas 1/1e6) — kita toleransi dengan meminta ulang.
    if (r.status === 200) {
      const otp = await requestOtpFor(email);
      const r2 = await post('/auth/verify-otp', { email, otp: otp === '000000' ? '000001' : '000000' });
      if (r2.status !== 401) throw new Error(`ingin 401, dapat ${r2.status}`);
    } else if (r.status !== 401) {
      throw new Error(`ingin 401, dapat ${r.status}`);
    }
  });

  await test('verify-otp: OTP benar -> 200 + JWT', async () => {
    const email = uniq('ok');
    const otp = await requestOtpFor(email);
    const r = await post('/auth/verify-otp', { email, otp });
    if (r.status !== 200 || !r.body.token || r.body.user?.email !== email.toLowerCase()) {
      throw new Error(`ingin token + user, dapat ${JSON.stringify(r.body)}`);
    }
  });

  await test('OTP sekali pakai: verifikasi kedua -> 401', async () => {
    const email = uniq('once');
    const otp = await requestOtpFor(email);
    const r1 = await post('/auth/verify-otp', { email, otp });
    if (r1.status !== 200) throw new Error('verifikasi pertama harus sukses');
    const r2 = await post('/auth/verify-otp', { email, otp });
    if (r2.status !== 401) throw new Error(`OTP harus sekali pakai, dapat ${r2.status}`);
  });

  await test('auth/me: token valid -> user', async () => {
    const email = uniq('me');
    const otp = await requestOtpFor(email);
    const v = await post('/auth/verify-otp', { email, otp });
    const r = await get('/auth/me', { Authorization: `Bearer ${v.body.token}` });
    if (r.status !== 200 || r.body.user?.email !== email.toLowerCase()) {
      throw new Error(`ingin user, dapat ${JSON.stringify(r.body)}`);
    }
  });

  await test('auth/me: token rusak -> 401', async () => {
    const r = await get('/auth/me', { Authorization: 'Bearer bogus.token.here' });
    if (r.status !== 401) throw new Error(`ingin 401, dapat ${r.status}`);
  });

  await test('auth/google: tanpa GOOGLE_CLIENT_ID -> 503', async () => {
    const r = await post('/auth/google', { id_token: 'fake' });
    if (r.status !== 503 || r.body.error !== 'google-not-configured') {
      throw new Error(`ingin 503, dapat ${r.status} ${JSON.stringify(r.body)}`);
    }
  });

  console.log(`\nHasil: ${passed} lulus, ${failed} gagal`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
