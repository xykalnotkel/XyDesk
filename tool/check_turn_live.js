#!/usr/bin/env node
// tool/check_turn_live.js — Verifikasi TURN live pasca-deploy
// Dipakai Operator untuk memastikan secret TURN beneran kepasang, bukan cuma diisi di GitHub Secrets tapi tidak diteruskan worker.
// Sesuai temuan AUDIT-2026-09-06: deploy-signaling.yml dulu tidak pernah meneruskan secret TURN sama sekali.
//
// Cara pakai:
//   ADMIN_SECRET=xxx node tool/check_turn_live.js
//   ADMIN_SECRET=xxx SIGNAL_URL=https://signal.xydesk.my.id node tool/check_turn_live.js
//
// Harus: providers[0].ok=true, iceServers.length>0
// Kalau kosong: berarti secret belum kepasang atau salah pasang (statis butuh URL+SECRET sepasang).

const SIGNAL_URL = process.env.SIGNAL_URL || 'https://signal.xydesk.my.id';
const ADMIN_SECRET = process.env.ADMIN_SECRET || process.env.ADMIN_TOKEN;

if (!ADMIN_SECRET) {
  console.error('Butuh ADMIN_SECRET env. Contoh: ADMIN_SECRET=xxx node tool/check_turn_live.js');
  process.exit(1);
}

async function main() {
  const url = `${SIGNAL_URL.replace(/\/$/, '')}/turn-ice`;
  console.log(`→ GET ${url} dengan X-Admin header`);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);

  let res;
  try {
    res = await fetch(url, {
      headers: { 'X-Admin': ADMIN_SECRET },
      signal: controller.signal,
    });
  } catch (e) {
    console.error(`✗ Fetch gagal: ${e.message}`);
    console.error('  Cek: SIGNAL_URL benar? Worker hidup? /healthz 200?');
    process.exit(2);
  } finally {
    clearTimeout(timeout);
  }

  console.log(`  Status: ${res.status} ${res.statusText}`);

  if (res.status === 403) {
    console.error('✗ 403 — X-Admin salah atau tidak dikirim. Ini bukan berarti TURN rusak, tapi kamu tidak bawa kuncinya.');
    process.exit(3);
  }

  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    console.error(`✗ HTTP ${res.status}: ${txt.slice(0, 500)}`);
    process.exit(4);
  }

  let data;
  try {
    data = await res.json();
  } catch (e) {
    console.error(`✗ Balasan bukan JSON: ${e.message}`);
    process.exit(5);
  }

  console.log('\n--- iceServers ---');
  const ice = data.iceServers || [];
  console.log(`  Jumlah: ${ice.length}`);
  ice.forEach((s, i) => {
    const urls = Array.isArray(s.urls) ? s.urls.join(', ') : s.urls;
    console.log(`  [${i}] urls=${urls} username=${s.username?.slice(0, 30)}...`);
  });

  console.log('\n--- providers ---');
  const prov = data.providers || [];
  if (prov.length === 0) {
    console.log('  (tidak ada field providers — worker versi lama, sebelum multi-provider)');
  } else {
    prov.forEach(p => {
      const ok = p.ok ? '✓ OK' : '✗ GAGAL';
      const ms = p.ms ? `${p.ms}ms` : '-';
      const cached = p.cached ? ' (cached)' : '';
      console.log(`  ${ok} ${p.id} ${ms}${cached} ${p.error ? `error=${p.error}` : ''}`);
    });
  }

  console.log('\n--- penilaian ---');
  if (ice.length === 0) {
    console.error('✗ iceServers kosong → client akan jalan STUN saja. Dua device di CGNAT tidak akan pernah connect.');
    console.error('  Isi secret TURN: TURN_STATIC_URLS + TURN_STATIC_SECRET (ExpressTurn) paling murah tanpa kartu kredit.');
    console.error('  Lihat cloudflare/README.md §Memilih penyedia TURN');
    process.exit(6);
  }

  const anyOk = prov.length === 0 ? true : prov.some(p => p.ok);
  if (!anyOk) {
    console.error('✗ Semua provider gagal → iceServers mungkin dari cache lama atau kosong. Cek log worker.');
    process.exit(7);
  }

  const staticOk = prov.find(p => p.id === 'statis')?.ok;
  if (staticOk) {
    console.log('✓ TURN static OK — ini yang paling penting (tanpa panggilan jaringan, selalu hidup)');
  } else if (prov.some(p => p.id === 'statis')) {
    console.warn('⚠ TURN static ada tapi gagal — cek TURN_STATIC_URLS + SECRET sepasang, jangan separuh.');
  } else {
    console.warn('⚠ TURN static tidak dikonfigurasi — disarankan isi ini dulu sebagai dasar.');
  }

  console.log('\n✓ TURN live dan siap dipakai client.');
  console.log('  Next: ukur koneksi nyata 2 device di jaringan berbeda (satu pakai hotspot HP = CGNAT).');
}

main();
