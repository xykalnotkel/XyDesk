import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';

import worker from '../src/worker.js';
import {
  collectIceServers,
  normalize,
  resetTurnCache,
  staticCredentials,
  TURN_PROVIDERS,
} from '../src/turn.js';

const SECRET = 'rahasia-turn-uji';

function denganFetch(handler, fn) {
  const asli = globalThis.fetch;
  globalThis.fetch = handler;
  return Promise.resolve()
    .then(fn)
    .finally(() => {
      globalThis.fetch = asli;
      resetTurnCache();
    });
}

test('kredensial secret statis mengikuti skema coturn/ExpressTurn', async () => {
  const now = 1_800_000_000;
  const c = await staticCredentials({ secret: SECRET, user: 'xydesk', ttl: 3600, now });
  assert.equal(c.username, `${now + 3600}:xydesk`);
  // credential = base64(HMAC-SHA1(secret, username)) — dihitung ulang di sini
  // dengan pustaka Node, bukan dengan kode yang diuji.
  const expect = createHmac('sha1', SECRET).update(c.username).digest('base64');
  assert.equal(c.credential, expect);
});

test('bentuk balasan penyedia dinormalisasi: array polos maupun objek', () => {
  const arr = [{ urls: 'turn:a:3478', username: 'u', credential: 'c' }];
  assert.deepEqual(normalize(arr).iceServers, arr);
  assert.deepEqual(normalize({ iceServers: arr }).iceServers, arr);
  assert.deepEqual(normalize({ aneh: true }).iceServers, []);
});

test('beberapa penyedia digabung jadi satu daftar', async () => {
  const env = {
    TURN_STATIC_URLS: 'turn:free.expressturn.com:3478,turn:free.expressturn.com:3478?transport=tcp',
    TURN_STATIC_SECRET: SECRET,
    TURN_KEY_ID: 'kid',
    TURN_KEY_TOKEN: 'ktoken',
    OPENRELAY_API_KEY: 'orel',
  };
  await denganFetch(
    async (url) => {
      if (String(url).includes('rtc.live.cloudflare.com')) {
        return new Response(JSON.stringify({ iceServers: [{ urls: 'turn:cf:3478', username: 'a', credential: 'b' }] }), { status: 200 });
      }
      if (String(url).includes('openrelayproject')) {
        return new Response(JSON.stringify([{ urls: 'turn:or:3478', username: 'c', credential: 'd' }]), { status: 200 });
      }
      throw new Error('url tak dikenal: ' + url);
    },
    async () => {
      const r = await collectIceServers(env, { ttl: 3600 });
      assert.equal(r.providers.length, 3, 'tiga penyedia ikut serta');
      assert.ok(r.providers.every((p) => p.ok));
      assert.equal(r.iceServers.length, 3);
      // Penyedia statis ikut serta walau dua lainnya yang dipanggil jaringan.
      assert.ok(r.iceServers.some((s) => JSON.stringify(s.urls).includes('expressturn')));
      assert.ok(r.iceServers.some((s) => String(s.urls).includes('cf')));
      assert.ok(r.iceServers.some((s) => String(s.urls).includes('or')));
    },
  );
});

test('penyedia yang gagal tidak menggagalkan yang lain', async () => {
  const env = {
    TURN_STATIC_URLS: 'turn:statis:3478',
    TURN_STATIC_SECRET: SECRET,
    OPENRELAY_API_KEY: 'orel',
  };
  await denganFetch(
    async () => new Response('down', { status: 500 }),
    async () => {
      const r = await collectIceServers(env, { ttl: 3600 });
      const gagal = r.providers.find((p) => p.id === 'openrelay');
      assert.equal(gagal.ok, false);
      assert.match(gagal.error, /500/);
      // Penyedia statis tetap menghasilkan kredensial: ia tidak butuh
      // jaringan, jadi tetap menjadi jalan keluar terakhir yang hidup.
      assert.equal(r.iceServers.length, 1);
      assert.ok(r.iceServers[0].username.includes(':'));
    },
  );
});

test('hasil disimpan sebentar — penyedia tidak dipanggil dua kali', async () => {
  const env = { TURN_STATIC_URLS: 'turn:statis:3478', TURN_STATIC_SECRET: SECRET, OPENRELAY_API_KEY: 'k' };
  let panggil = 0;
  await denganFetch(
    async () => {
      panggil += 1;
      return new Response(JSON.stringify([{ urls: 'turn:or:3478', username: 'u', credential: 'c' }]), { status: 200 });
    },
    async () => {
      await collectIceServers(env, { ttl: 3600 });
      await collectIceServers(env, { ttl: 3600 });
      assert.equal(panggil, 1, 'panggilan kedua memakai tembolok');
    },
  );
});

test('tanpa autentikasi, /turn-ice berhenti di gerbang', async () => {
  const res = await worker.fetch(
    new Request('https://signal.example/turn-ice?id=123456789&token=abc'),
    { XYDESK_SECRET: 's', CORS_ORIGINS: '*' },
    {},
  );
  assert.equal(res.status, 403); // bukan 503: TURN tidak pernah dibocorkan
});

test('tanpa penyedia terkonfigurasi: /turn-ice menjawab 503 dengan petunjuk', async () => {
  const res = await worker.fetch(
    new Request('https://signal.example/turn-ice?id=123456789', {
      headers: { 'X-Admin': 'admin-uji' },
    }),
    { XYDESK_SECRET: 's', CORS_ORIGINS: '*', ADMIN_SECRET: 'admin-uji' },
    {},
  );
  assert.equal(res.status, 503);
  const body = await res.json();
  assert.equal(body.error, 'turn-not-configured');
  // Petunjuknya menyebut jalur termurah lebih dulu: secret statis tak perlu
  // kartu kredit dan tak perlu panggilan jaringan.
  assert.match(body.hint, /TURN_STATIC_URLS/);
  assert.match(body.hint, /ExpressTurn|coturn/);
});

test('/turn-ice mengembalikan gabungan penyedia plus diagnostik', async () => {
  const env = {
    XYDESK_SECRET: 's',
    CORS_ORIGINS: '*',
    TURN_STATIC_URLS: 'turn:statis:3478',
    TURN_STATIC_SECRET: SECRET,
    TURN_KEY_ID: 'kid',
    TURN_KEY_TOKEN: 'ktoken',
  };
  await denganFetch(
    async () =>
      new Response(
        JSON.stringify({ iceServers: [{ urls: 'turn:cf:3478', username: 'a', credential: 'b' }] }),
        { status: 200 },
      ),
    async () => {
      const id = '123456789';
      // Token sah diperlukan untuk melewati gerbang /turn-ice.
      const tokenHost = await worker.fetch(
        new Request('https://signal.example/host-token', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ id, refresh: 'x', claim: ' password ' }),
        }),
        env,
        {},
      );
      assert.equal(tokenHost.status, 401); // kredensial penyegaran palsu
      // Ambil token lewat jalur /issue butuh ADMIN_SECRET; pakai itu.
      const issued = await worker.fetch(
        new Request('https://signal.example/issue?purpose=' + id + '&role=client', {
          headers: { 'X-Admin': 'admin-uji' },
        }),
        { ...env, ADMIN_SECRET: 'admin-uji' },
        {},
      );
      assert.equal(issued.status, 200);
      const token = (await issued.text()).trim();

      const res = await worker.fetch(
        new Request(`https://signal.example/turn-ice?id=${id}&token=${token}`),
        env,
        {},
      );
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.iceServers.length, 2, 'statis + cloudflare');
      assert.equal(body.degraded, false);
      assert.ok(body.providers.every((p) => p.ok));
    },
  );
});

test('daftar penyedia terdokumentasi dan punya penanganan', () => {
  for (const p of TURN_PROVIDERS) {
    assert.ok(p.id && p.kind, 'penyedia butuh id dan kind');
    assert.ok(['static', 'cloudflare', 'rest'].includes(p.kind), `kind tak dikenal: ${p.kind}`);
  }
});

// ── Paralel + batas waktu per penyedia ─────────────────────────────────────
//
// Sebelumnya penyedia dipanggil berurutan di dalam `for` + `await` dan tidak
// ada satu pun batas waktu. Client membatasi `/turn-ice` pada 5 detik
// (`lib/webrtc/rtc_service.dart`) dan gagal secara diam-diam, jadi satu
// penyedia REST yang lambat membuat seluruh permintaan lewat batas: client
// jatuh ke STUN saja tanpa pesan, dan dua perangkat di belakang NAT
// simetris/CGNAT tidak pernah tersambung. Tiga uji di bawah mengunci
// perbaikannya.

const ENV_JARINGAN = {
  TURN_STATIC_URLS: 'turn:statis:3478',
  TURN_STATIC_SECRET: SECRET,
  TURN_KEY_ID: 'kid',
  TURN_KEY_TOKEN: 'ktoken',
  OPENRELAY_API_KEY: 'orel',
};

function tidur(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

test('penyedia dipanggil bersamaan, bukan berurutan', async () => {
  const TUNDA = 150;
  await denganFetch(
    async () => {
      await tidur(TUNDA);
      return new Response(JSON.stringify([{ urls: 'turn:x:3478', username: 'u', credential: 'c' }]), {
        status: 200,
      });
    },
    async () => {
      const mulai = Date.now();
      const r = await collectIceServers(ENV_JARINGAN, { ttl: 3600 });
      const lewat = Date.now() - mulai;

      assert.equal(r.providers.filter((p) => p.ok).length, 3);
      // Dua penyedia jaringan (cloudflare + openrelay) masing-masing menunda
      // 150 ms. Berurutan = >= 300 ms; bersamaan = jauh di bawah itu.
      assert.ok(
        lewat < TUNDA * 2,
        `waktu total ${lewat} ms — penyedia tampaknya masih dipanggil berurutan`,
      );
    },
  );
});

test('penyedia yang melewati batas waktu dilaporkan gagal, yang lain tetap jalan', async () => {
  await denganFetch(
    async (url, options) => {
      if (String(url).includes('openrelayproject')) {
        // Menghormati signal abort, seperti fetch sungguhan.
        return new Promise((_, reject) => {
          const signal = options?.signal;
          if (signal) {
            if (signal.aborted) return reject(new Error('aborted'));
            signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
          }
          // Tidak pernah selesai dengan sendirinya.
        });
      }
      return new Response(JSON.stringify({ iceServers: [{ urls: 'turn:cf:3478', username: 'a', credential: 'b' }] }), {
        status: 200,
      });
    },
    async () => {
      // `AbortSignal.timeout()` di Node memasang timer yang di-unref, jadi
      // tanpa penahan ini event loop bisa selesai lebih dulu dan uji dibatalkan
      // ("Promise resolution is still pending"). Di runtime Workers hal ini
      // tidak berlaku — penahan ini murni kebutuhan Node.
      const penahan = setTimeout(() => {}, 3000);
      try {
        const r = await collectIceServers(ENV_JARINGAN, { ttl: 3600, timeoutMs: 40 });

        const lambat = r.providers.find((p) => p.id === 'openrelay');
        assert.equal(lambat.ok, false, 'penyedia lambat harus dilaporkan gagal');
        assert.match(lambat.error, /abort/i);

        // Yang penting: kegagalan satu penyedia TIDAK mematikan yang lain.
        // Penyedia statis tidak butuh jaringan sama sekali, jadi ia selalu
        // hidup — inilah alasan jenis penyedia itu paling berharga sebagai dasar.
        assert.ok(r.providers.find((p) => p.id === 'statis').ok);
        assert.ok(r.providers.find((p) => p.id === 'cloudflare').ok);
        assert.ok(r.iceServers.length >= 2);
      } finally {
        clearTimeout(penahan);
      }
    },
  );
});

test('signal batas waktu diteruskan ke fetch', async () => {
  let signalDiterima = 0;
  await denganFetch(
    async (_url, options) => {
      if (options?.signal) signalDiterima += 1;
      return new Response(JSON.stringify([]), { status: 200 });
    },
    async () => {
      await collectIceServers(ENV_JARINGAN, { ttl: 3600, timeoutMs: 500 });
      // Dua penyedia jaringan dipanggil; keduanya harus menerima signal.
      assert.equal(signalDiterima, 2);
    },
  );
});

test('urutan keluaran mengikuti deklarasi, bukan urutan selesai', async () => {
  await denganFetch(
    async (url) => {
      // Cloudflare dibuat paling lambat supaya urutan selesai terbalik dari
      // urutan deklarasi. Balasan tetap harus deterministik.
      if (String(url).includes('rtc.live.cloudflare.com')) await tidur(60);
      return new Response(JSON.stringify([{ urls: 'turn:x:3478', username: 'u', credential: 'c' }]), {
        status: 200,
      });
    },
    async () => {
      const r = await collectIceServers(ENV_JARINGAN, { ttl: 3600 });
      assert.deepEqual(
        r.providers.map((p) => p.id),
        ['statis', 'cloudflare', 'openrelay'],
      );
    },
  );
});
