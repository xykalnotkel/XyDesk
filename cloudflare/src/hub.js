// XyDesk hub — Durable Object yang memegang registri perangkat & merelay
// pesan signaling. Menggunakan WebSocket Hibernation API: saat tidak ada
// pesan, DO "tidur" tanpa memakan CPU — murah & gratis.
//
// Satu DO global cukup untuk skala personal (signaling itu KB per sesi).
// Skala besar nanti: shard by prefix (idFromName('shard-' + id[0])).

const ROLE_HOST = 'host';

// ── Rem pairing sisi server ──────────────────────────────────────────────
//
// Kenapa di server dan bukan di host: host hanya tahu password benar atau
// salah — ia tidak tahu SIAPA yang mencoba, karena semua peer datang lewat
// relay. Rem di host karena itu terpaksa dihukum ke semua orang, dan itu
// berubah menjadi senjata melawan pemiliknya sendiri: siapa pun yang tahu ID
// 9 digit bisa mengirim sepuluh tebakan salah dan mengunci pemilik PC keluar
// dari mesinnya sendiri selama 15 menit (itulah `GLOBAL_LOCKOUT` yang dulu ada
// di host/src/pairguard.rs).
//
// Di server, kuncinya dipasang per (host, client) dan per (host, IP). Yang
// dihukum adalah penebaknya: pemilik PC yang memakai client/IP lain tetap
// bisa masuk, dan host lain tidak terpengaruh sama sekali.
export const PAIR_BRAKE = {
  // Jendela penghitungan kegagalan (detik).
  windowSeconds: 10 * 60,
  // Per client: satu perangkat/aplikasi yang berulang kali salah password.
  client: { maxFailures: 5, lockoutSeconds: 5 * 60 },
  // Per IP: menyapu banyak client dari satu tempat (client id gampang diganti,
  // IP tidak).
  ip: { maxFailures: 10, lockoutSeconds: 15 * 60 },
};

/// Catatan kegagalan baru. `locked_until` = 0 berarti tidak terkunci.
export function brakeNew(now) {
  return { count: 0, started_at: now, locked_until: 0 };
}

/// Keadaan satu catatan: sedang mengunci, sudah lewat, atau masih menghitung.
///
/// `expired` dipisah dari "tidak terkunci" supaya pemanggil bisa membersihkan
/// catatan lama — storage DO tidak punya TTL.
export function brakeState(entry, now) {
  if (!entry) return { locked: false, retryIn: 0, expired: false };
  if (entry.locked_until && entry.locked_until > now) {
    return { locked: true, retryIn: entry.locked_until - now, expired: false };
  }
  if (entry.locked_until) return { locked: false, retryIn: 0, expired: true };
  if (now - entry.started_at >= PAIR_BRAKE.windowSeconds) {
    return { locked: false, retryIn: 0, expired: true };
  }
  return { locked: false, retryIn: 0, expired: false };
}

/// Catat satu kegagalan pairing dan kembalikan catatan berikutnya.
///
/// Kebijakan (`maxFailures`, `lockoutSeconds`) diserahkan pemanggil karena dua
/// lingkup memakai angka berbeda. Jendela yang sudah lewat dihitung ulang dari
/// nol — pengguna sah yang salah ketik bulan lalu tidak boleh dihukum hari ini.
export function brakeRecordFailure(entry, now, policy) {
  const state = brakeState(entry, now);
  const base = state.expired || !entry ? brakeNew(now) : entry;
  const next = { ...base, count: base.count + 1 };
  if (next.count >= policy.maxFailures) {
    return {
      entry: { ...next, count: 0, locked_until: now + policy.lockoutSeconds },
      locked: true,
      retryIn: policy.lockoutSeconds,
    };
  }
  return { entry: next, locked: false, retryIn: 0 };
}

export class Hub {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  // Upgrade WebSocket dari Worker. Attachment menyimpan metadata per koneksi
  // yang bertahan melewati hibernasi (jadi tak butuh Map yang mudah hilang).
  async fetch(request) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    const meta = {
      id: request.headers.get('x-xydesk-id') || '',
      role: request.headers.get('x-xydesk-role') || 'client',
      name: request.headers.get('x-xydesk-name') || '',
      registered: false,
      since: 0,
      // Alamat jaringan client, dipakai rem pairing lingkup IP. Host tidak
      // pernah melihatnya (dan tidak perlu): yang ia terima cuma hasil
      // pairing, sedangkan keputusan "siapa yang boleh mencoba lagi" ada di
      // sini. IP tidak disimpan mentah — lihat `brakeKey`.
      ip: request.headers.get('CF-Connecting-IP') || '',
    };
    server.serializeAttachment(meta);

    this.ctx.acceptWebSocket(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    let msg;
    try {
      msg = typeof message === 'string' ? JSON.parse(message) : JSON.parse(new TextDecoder().decode(message));
    } catch {
      return;
    }

    switch (msg.type) {
      case 'hello':
        return this.handleHello(ws, msg);
      case 'list':
        // Tanpa registri kepemilikan, daftar global akan membocorkan semua ID
        // host ke setiap akun. Koneksi langsung tetap bekerja lewat ID tujuan.
        return this.send(ws, { type: 'devices', devices: [] });
      case 'ping':
        return this.send(ws, { type: 'pong' });
      case 'pair':
      case 'pair-response':
      case 'offer':
      case 'answer':
      case 'ice':
      case 'bye':
        return this.relay(ws, msg);
      default:
        return this.send(ws, { type: 'error', error: 'tipe tak dikenal', reason: msg.type });
    }
  }

  handleHello(ws, msg) {
    const meta = ws.deserializeAttachment();
    const id = meta.id;
    if (!id) return this.send(ws, { type: 'error', error: 'hello butuh id perangkat' });
    // ID dan role berasal dari query yang sudah diverifikasi Worker. Payload
    // WebSocket tidak boleh menggantinya setelah melewati gerbang auth.
    if (msg.to && msg.to !== id) {
      return this.send(ws, { type: 'error', error: 'id tidak cocok dengan token' });
    }

    // Tolak id duplikat (mencegah pencurian sesi).
    const dup = this.sockets().find((w) => {
      const a = w.deserializeAttachment();
      return a && a.registered && a.id === id && w !== ws;
    });
    if (dup) return this.send(ws, { type: 'error', error: 'id sudah online' });

    meta.id = id;
    meta.registered = true;
    meta.role = meta.role === ROLE_HOST ? ROLE_HOST : 'client';
    meta.name = msg.from || meta.name || id;
    meta.since = Math.floor(Date.now() / 1000);
    ws.serializeAttachment(meta);

    this.send(ws, { type: 'welcome', from: id });
  }

  // Relay antar peer; server selalu menimpa `from` dengan id pengirim agar
  // peer tak bisa memalsukan identitas. Media (SDP/ICE) tidak disentuh.
  //
  // Async karena dua tipe pesan butuh storage: `pair` (periksa rem sebelum
  // diteruskan) dan `pair-response` (catat hasilnya). Tipe lain tidak
  // menyentuh storage sama sekali — jalurnya tetap satu hop.
  async relay(ws, msg) {
    const meta = ws.deserializeAttachment();
    const toId = msg.to;
    if (!meta?.registered) {
      return this.send(ws, { type: 'error', error: 'hello wajib sebelum relay' });
    }
    if (!toId) return this.send(ws, { type: 'error', error: 'to wajib', reason: msg.type });

    const peer = this.sockets().find((w) => {
      const a = w.deserializeAttachment();
      return a && a.registered && a.id === toId;
    });
    if (!peer) return this.send(ws, { type: 'error', error: 'peer-offline', reason: toId });

    const target = peer.deserializeAttachment();
    if (!this.relayAllowed(msg.type, meta.role, target.role)) {
      return this.send(ws, { type: 'error', error: 'arah relay ditolak', reason: msg.type });
    }

    if (msg.type === 'pair') {
      // meta = client yang mencoba, toId = host yang dituju.
      const block = await this.pairBlocked(toId, meta.id, meta.ip);
      if (block) {
        // Tidak diteruskan ke host: percobaan yang sudah dikunci tidak boleh
        // membebani PC orang lain, dan client mendapat alasan + sisa waktunya
        // (bukan "pairing ditolak" tanpa penjelasan).
        return this.send(ws, {
          type: 'error',
          error: 'pair-terkunci',
          reason: block.scope,
          retry_in: block.retryIn,
        });
      }
    }

    peer.send(JSON.stringify({ ...msg, from: meta.id }));

    if (msg.type === 'pair-response') {
      // meta = host yang menjawab, target = client yang mencoba.
      await this.recordPairResult(meta.id, target.id, target.ip, msg.accepted === true);
    }
  }

  /// Benar bila client ini (atau IP-nya) sedang dikunci untuk host itu.
  /// Mengembalikan `{ scope, retryIn }` atau `null`.
  async pairBlocked(hostId, clientId, clientIp) {
    const now = Math.floor(Date.now() / 1000);
    for (const scope of ['client', 'ip']) {
      const ident = scope === 'client' ? clientId : clientIp;
      if (!ident) continue;
      const key = await this.brakeKey(scope, hostId, ident);
      const entry = await this.ctx.storage.get(key);
      const state = brakeState(entry, now);
      if (state.locked) return { scope, retryIn: state.retryIn };
      // Storage DO tidak punya TTL: catatan basi dibersihkan saat terbaca.
      if (state.expired && entry) await this.ctx.storage.delete(key);
    }
    return null;
  }

  /// Catat hasil pairing. Sukses membersihkan lingkup client (salah ketik
  /// bukan percobaan membobol); gagal menambah hitungan di dua lingkup.
  async recordPairResult(hostId, clientId, clientIp, accepted) {
    const now = Math.floor(Date.now() / 1000);
    if (accepted) {
      if (clientId) {
        await this.ctx.storage.delete(await this.brakeKey('client', hostId, clientId));
      }
      return;
    }
    for (const [scope, ident, policy] of [
      ['client', clientId, PAIR_BRAKE.client],
      ['ip', clientIp, PAIR_BRAKE.ip],
    ]) {
      if (!ident) continue;
      const key = await this.brakeKey(scope, hostId, ident);
      const entry = await this.ctx.storage.get(key);
      const result = brakeRecordFailure(entry, now, policy);
      await this.ctx.storage.put(key, result.entry);
    }
  }

  /// Kunci storage satu lingkup rem. IP di-hash (HMAC) lebih dulu: catatan
  /// kegagalan tidak perlu menyimpan alamat jaringan mentah, dan kebocoran
  /// storage tidak boleh berubah menjadi daftar IP pengguna.
  async brakeKey(scope, hostId, ident) {
    if (scope !== 'ip') return `pairbrake:c:${hostId}:${ident}`;
    return `pairbrake:i:${hostId}:${await this.hashIdent(ident)}`;
  }

  async hashIdent(value) {
    const secret = this.env?.XYDESK_SECRET || 'xydesk-pair-brake';
    const enc = new TextEncoder();
    try {
      const key = await crypto.subtle.importKey(
        'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
      );
      const sig = await crypto.subtle.sign('HMAC', key, enc.encode(`pairbrake\x00${value}`));
      return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
    } catch {
      // Environment tanpa WebCrypto (uji lama): tetap jangan simpan mentah.
      return `len${value.length}-${value.split('').reduce((a, c) => (a * 31 + c.charCodeAt(0)) % 2147483647, 7)}`;
    }
  }

  relayAllowed(type, fromRole, toRole) {
    if (type === 'pair' || type === 'offer') {
      return fromRole === 'client' && toRole === ROLE_HOST;
    }
    if (type === 'pair-response' || type === 'answer') {
      return fromRole === ROLE_HOST && toRole === 'client';
    }
    // ICE dan bye sah dua arah, tetapi tidak pernah sesama role.
    return (type === 'ice' || type === 'bye') && fromRole !== toRole;
  }

  send(ws, msg) {
    try { ws.send(JSON.stringify(msg)); } catch { /* abaikan */ }
  }

  sockets() {
    return this.ctx.getWebSockets();
  }

  async webSocketClose(ws) {
    ws.close(1011, 'closed');
  }

  async webSocketError(ws) {
    ws.close(1011, 'error');
  }
}
