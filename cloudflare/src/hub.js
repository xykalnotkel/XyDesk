// XyDesk hub — Durable Object yang memegang registri perangkat & merelay
// pesan signaling. Menggunakan WebSocket Hibernation API: saat tidak ada
// pesan, DO "tidur" tanpa memakan CPU — murah & gratis.
//
// Satu DO global cukup untuk skala personal (signaling itu KB per sesi).
// Skala besar nanti: shard by prefix (idFromName('shard-' + id[0])).

const ROLE_HOST = 'host';

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
        return this.send(ws, { type: 'devices', devices: this.snapshot() });
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
    const id = msg.to || meta.id;
    if (!id) return this.send(ws, { type: 'error', error: 'hello butuh id perangkat' });

    // Tolak id duplikat (mencegah pencurian sesi).
    const dup = this.sockets().find((w) => {
      const a = w.deserializeAttachment();
      return a && a.registered && a.id === id && w !== ws;
    });
    if (dup) return this.send(ws, { type: 'error', error: 'id sudah online' });

    meta.id = id;
    meta.registered = true;
    meta.role = msg.reason === ROLE_HOST ? ROLE_HOST : 'client';
    meta.name = msg.from || meta.name || id;
    meta.since = Math.floor(Date.now() / 1000);
    ws.serializeAttachment(meta);

    this.send(ws, { type: 'welcome', from: id });
    this.broadcast({ type: 'devices', devices: this.snapshot() });
  }

  // Relay antar peer; server selalu menimpa `from` dengan id pengirim agar
  // peer tak bisa memalsukan identitas. Media (SDP/ICE) tidak disentuh.
  relay(ws, msg) {
    const meta = ws.deserializeAttachment();
    const toId = msg.to;
    if (!toId) return this.send(ws, { type: 'error', error: 'to wajib', reason: msg.type });

    const peer = this.sockets().find((w) => {
      const a = w.deserializeAttachment();
      return a && a.registered && a.id === toId;
    });
    if (!peer) return this.send(ws, { type: 'error', error: 'peer-offline', reason: toId });

    peer.send(JSON.stringify({ ...msg, from: meta.id }));
  }

  snapshot() {
    return this.sockets()
      .map((w) => w.deserializeAttachment())
      .filter((a) => a && a.registered)
      .map((a) => ({ id: a.id, name: a.name, role: a.role, online: true, since: a.since }));
  }

  broadcast(msg) {
    const text = JSON.stringify(msg);
    for (const w of this.sockets()) {
      try { w.send(text); } catch { /* peer baru saja putus */ }
    }
  }

  send(ws, msg) {
    try { ws.send(JSON.stringify(msg)); } catch { /* abaikan */ }
  }

  sockets() {
    return this.ctx.getWebSockets();
  }

  async webSocketClose(ws) {
    const meta = ws.deserializeAttachment();
    if (meta && meta.registered) {
      this.broadcast({ type: 'devices', devices: this.snapshot() });
    }
    ws.close(1011, 'closed');
  }

  async webSocketError(ws) {
    ws.close(1011, 'error');
  }
}
