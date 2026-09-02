// Sesi WebRTC client browser — cermin dari lib/webrtc/rtc_service.dart.
// Protokol signaling identik (hello/pair/offer/answer/ice/bye) dan protokol
// input biner identik dengan host/src/input.rs (little-endian, 8 byte).

import { signalToken, turnIce, WS_URL } from './api';

export type RtcPhase =
  | 'pairing'
  | 'negotiating'
  | 'connected'
  | 'rejected'
  | 'peer-offline'
  | 'host-busy'
  | 'ended';

interface SignalMessage {
  type: string;
  to?: string;
  from?: string;
  pin?: string;
  accepted?: boolean;
  sdp?: { type: string; sdp: string };
  candidate?: {
    candidate: string;
    sdpMid?: string | null;
    sdpMLineIndex?: number | null;
  };
  error?: string;
  reason?: string;
}

export const InputCodec = {
  mouseMoveRel(dx: number, dy: number): Uint8Array {
    const b = new Uint8Array(8);
    const v = new DataView(b.buffer);
    b[0] = 0x01;
    v.setInt16(1, Math.max(-32768, Math.min(32767, dx)), true);
    v.setInt16(3, Math.max(-32768, Math.min(32767, dy)), true);
    return b;
  },
  mouseMoveAbs(fx: number, fy: number): Uint8Array {
    const b = new Uint8Array(8);
    const v = new DataView(b.buffer);
    b[0] = 0x02;
    v.setUint16(1, Math.round(Math.max(0, Math.min(1, fx)) * 65535), true);
    v.setUint16(3, Math.round(Math.max(0, Math.min(1, fy)) * 65535), true);
    return b;
  },
  mouseButton(button: number, down: boolean): Uint8Array {
    const b = new Uint8Array(8);
    b[0] = 0x03;
    b[1] = button;
    b[2] = down ? 1 : 0;
    return b;
  },
  scroll(dx: number, dy: number): Uint8Array {
    const b = new Uint8Array(8);
    const v = new DataView(b.buffer);
    b[0] = 0x04;
    v.setInt16(1, Math.max(-32768, Math.min(32767, dx)), true);
    v.setInt16(3, Math.max(-32768, Math.min(32767, dy)), true);
    return b;
  },
  key(vk: number, down: boolean): Uint8Array {
    const b = new Uint8Array(8);
    const v = new DataView(b.buffer);
    b[0] = 0x05;
    v.setUint16(1, vk, true);
    b[3] = down ? 1 : 0;
    return b;
  },
  /// Teks bebas (clipboard/keyboard virtual) — host mengetik sebagai
  /// unicode, bebas layout keyboard host.
  text(s: string): Uint8Array {
    const utf8 = new TextEncoder().encode(s);
    const b = new Uint8Array(1 + utf8.length);
    b[0] = 0x06;
    b.set(utf8, 1);
    return b;
  },

  /// 0x08 CLIPBOARD_SET — isi papan klip, UTF-8 mulai byte 1.
  ///
  /// Sengaja terpisah dari 0x06 TEXT: TEXT berarti "ketikkan ini",
  /// CLIPBOARD_SET berarti "jadikan ini isi papan klipmu". Mencampurnya
  /// berarti setiap ketikan pengguna menimpa papan klip PC.
  clipboardSet(s: string): Uint8Array {
    const utf8 = new TextEncoder().encode(s);
    let end = Math.min(utf8.length, 64 * 1024);
    // Potong di batas karakter: ekor UTF-8 yang tidak lengkap membuat
    // penerima menolak SELURUH pesan, bukan sekadar kehilangan huruf ujung.
    while (end > 0 && (utf8[end - 1] & 0xc0) === 0x80) end--;
    const b = new Uint8Array(1 + end);
    b[0] = 0x08;
    b.set(utf8.subarray(0, end), 1);
    return b;
  },

  /// 0x09 CLIPBOARD_REQ — minta host mengirim isi papan klipnya. Ia
  /// membalas dengan 0x08, yang diteruskan lewat `onClipboard`.
  ///
  /// Model tarik, bukan pantau: host tidak punya pengamat papan klip
  /// Windows, jadi "PC → browser otomatis" tidak bisa dijanjikan tanpa
  /// berbohong.
  clipboardRequest(): Uint8Array {
    const b = new Uint8Array(8);
    b[0] = 0x09;
    return b;
  },

  /// Urai 0x08 yang datang dari host. `null` bila bukan pesan papan klip
  /// atau isinya bukan UTF-8 sah — jangan menuliskan byte rusak ke papan
  /// klip pengguna hanya karena paketnya berhasil lewat.
  decodeClipboardSet(b: Uint8Array): string | null {
    if (b.length === 0 || b[0] !== 0x08) return null;
    if (b.length - 1 > 64 * 1024) return null;
    if (b.length === 1) return '';
    try {
      return new TextDecoder('utf-8', { fatal: true }).decode(b.subarray(1));
    } catch {
      return null;
    }
  },
};

/// Meta host (layar + audio) — dikirim host lewat data channel input.
export interface HostDisplay {
  index: number;
  name: string;
  width: number;
  height: number;
}

export interface HostMeta {
  displays: HostDisplay[];
  wanted: number;
  audio: { available: boolean; pipeline: string };
}

export class RtcSession {
  private ws?: WebSocket;
  private pc?: RTCPeerConnection;
  private input?: RTCDataChannel;
  private deviceId = '';
  private token = '';
  private hostId = '';
  private stopped = false;
  private recoveryAttempt = 0;
  private recovering = false;
  private audioTransceiver?: RTCRtpTransceiver;
  private micStream?: MediaStream;

  onPhase: (phase: RtcPhase) => void = () => {};
  onTrack: (stream: MediaStream) => void = () => {};
  onAudioTrack: (stream: MediaStream) => void = () => {};
  onMeta: (meta: HostMeta) => void = () => {};
  /// Isi papan klip PC — balasan dari `requestClipboard()`.
  onClipboard: (text: string) => void = () => {};

  meta: HostMeta | null = null;
  micEnabled = false;

  async start(jwt: string, hostId: string, pin: string) {
    this.hostId = hostId.replace(/[\s-]/g, '');
    this.deviceId = `web-${Date.now() % 1000000}`;
    this.token = await signalToken(jwt, this.deviceId);

    this.onPhase('pairing');
    const ws = new WebSocket(
      `${WS_URL}?id=${this.deviceId}&role=client&token=${encodeURIComponent(this.token)}`,
    );
    this.ws = ws;

    ws.onopen = () => {
      this.send({ type: 'hello', to: this.deviceId, reason: 'client' });
      this.send({ type: 'pair', to: this.hostId, pin });
    };
    ws.onclose = () => {
      if (!this.stopped) this.onPhase('ended');
    };
    ws.onmessage = (ev) => void this.handle(JSON.parse(ev.data as string));
  }

  private send(m: SignalMessage) {
    this.ws?.send(JSON.stringify(m));
  }

  private async handle(m: SignalMessage) {
    switch (m.type) {
      case 'pair-response':
        if (!m.accepted) return this.onPhase('rejected');
        this.onPhase('negotiating');
        return this.negotiate();
      case 'answer':
        if (m.sdp) {
          await this.pc?.setRemoteDescription({
            type: 'answer',
            sdp: m.sdp.sdp,
          });
        }
        return;
      case 'ice':
        if (m.candidate?.candidate) {
          await this.pc?.addIceCandidate({
            candidate: m.candidate.candidate,
            sdpMid: m.candidate.sdpMid ?? undefined,
            sdpMLineIndex: m.candidate.sdpMLineIndex ?? undefined,
          });
        }
        return;
      case 'bye':
        return this.stop();
      case 'error':
        if (m.error === 'peer-offline') this.onPhase('peer-offline');
        // Host sibuk: sesi lain sedang berjalan — koneksi kedua ditolak
        // meski password benar (host melayani satu sesi pada satu waktu).
        if (m.error === 'host-sibuk') this.onPhase('host-busy');
        return;
    }
  }

  private async negotiate() {
    const iceServers: RTCIceServer[] = [
      { urls: ['stun:stun.cloudflare.com:3478'] },
    ];
    const turnServers = await turnIce(this.deviceId, this.token);
    iceServers.push(...turnServers);

    const pc = new RTCPeerConnection({
      iceServers,
      iceTransportPolicy: 'all',
      bundlePolicy: 'max-bundle',
    });
    this.pc = pc;

    pc.addTransceiver('video', { direction: 'recvonly' });
    // Audio dua arah (host → browser, dan mic browser → host).
    //
    // Arahnya HARUS sendrecv sejak offer pertama, bukan recvonly lalu
    // dinegosiasi ulang saat mic dinyalakan. Menurut aturan JSEP arah akhir
    // adalah irisan antara penawaran klien dan keinginan host: kalau klien
    // menawar recvonly, host menjawab sendonly — artinya host tidak pernah
    // menerima, dan track mic hasil getUserMedia terkirim ke mana-mana
    // kecuali ke host. Dengan sendrecv, addTrack(track mic) cukup menempel
    // ke transceiver yang sudah ada: tidak ada offer kedua, tidak ada
    // sesi yang dirombak (host membangun Session baru untuk setiap offer).
    this.audioTransceiver = pc.addTransceiver('audio', { direction: 'sendrecv' });
    this.input = pc.createDataChannel('input');
    this.input.onmessage = (ev) => {
      // Balasan biner: 0x08 CLIPBOARD_SET (isi papan klip PC).
      if (ev.data instanceof ArrayBuffer) {
        const teks = InputCodec.decodeClipboardSet(new Uint8Array(ev.data));
        if (teks !== null) this.onClipboard(teks);
        return;
      }
      // Host mengirim meta teks (layar + audio) di channel ini.
      if (typeof ev.data === 'string') {
        try {
          const data = JSON.parse(ev.data);
          if (data.type === 'meta') {
            this.meta = data as HostMeta;
            this.onMeta(this.meta);
          }
        } catch {
          /* meta tidak valid — abaikan */
        }
      }
    };

    pc.onicecandidate = (ev) => {
      if (!ev.candidate) return;
      this.send({
        type: 'ice',
        to: this.hostId,
        candidate: {
          candidate: ev.candidate.candidate,
          sdpMid: ev.candidate.sdpMid,
          sdpMLineIndex: ev.candidate.sdpMLineIndex,
        },
      });
    };
    pc.ontrack = (ev) => {
      if (ev.streams[0]) {
        if (ev.track.kind === 'video') this.onTrack(ev.streams[0]);
        else if (ev.track.kind === 'audio') this.onAudioTrack(ev.streams[0]);
      }
    };
    pc.onconnectionstatechange = () => {
      if (pc.connectionState === 'connected') {
        this.recoveryAttempt = 0;
        this.recovering = false;
        this.onPhase('connected');
      } else if (pc.connectionState === 'failed') {
        void this.recoverConnection();
      } else if (pc.connectionState === 'closed') {
        this.onPhase('ended');
      }
    };

    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    this.send({
      type: 'offer',
      to: this.hostId,
      sdp: { type: 'offer', sdp: offer.sdp ?? '' },
    });
  }

  private async recoverConnection() {
    const pc = this.pc;
    if (!pc || this.stopped || this.recovering) return;
    if (this.recoveryAttempt >= 2) {
      this.onPhase('ended');
      return;
    }
    this.recovering = true;
    this.recoveryAttempt += 1;
    this.onPhase('negotiating');
    try {
      // Percobaan pertama merotasi kandidat direct/STUN/TURN. Percobaan kedua
      // memaksa TURN relay, termasuk TURN TCP/TLS bila server menyediakannya.
      if (this.recoveryAttempt === 2) {
        pc.setConfiguration({
          ...pc.getConfiguration(),
          iceTransportPolicy: 'relay',
        });
      }
      pc.restartIce();
      const offer = await pc.createOffer({ iceRestart: true });
      await pc.setLocalDescription(offer);
      this.send({
        type: 'offer',
        to: this.hostId,
        sdp: { type: 'offer', sdp: offer.sdp ?? '' },
      });
    } catch {
      if (this.recoveryAttempt >= 2) this.onPhase('ended');
    } finally {
      this.recovering = false;
    }
  }

  sendInput(event: Uint8Array) {
    if (this.input?.readyState === 'open') this.input.send(event.buffer as ArrayBuffer);
  }

  /// Kirim isi papan klip browser ke PC (0x08 CLIPBOARD_SET).
  sendClipboard(text: string) {
    this.sendInput(InputCodec.clipboardSet(text));
  }

  /// Minta PC mengirim isi papan klipnya (0x09 CLIPBOARD_REQ).
  /// Hasilnya datang lewat `onClipboard`.
  requestClipboard() {
    this.sendInput(InputCodec.clipboardRequest());
  }

  /// 0x07 DISPLAY_SELECT — pindah monitor host.
  selectDisplay(index: number) {
    const b = new Uint8Array(8);
    b[0] = 0x07;
    b[1] = Math.max(0, Math.min(255, index | 0));
    this.sendInput(b);
  }

  /// Aktif/nonaktifkan pemutaran audio host.
  ///
  /// Menyeluruh `inactive` juga mematikan mic yang sedang dikirim, jadi
  /// keadaan "dibisukan" memakai `sendonly`: suara host berhenti, mic kamu
  /// tetap jalan.
  async setAudioEnabled(on: boolean) {
    if (!this.audioTransceiver) return;
    try {
      this.audioTransceiver.direction = on ? 'sendrecv' : 'sendonly';
    } catch {
      /* abaikan — audio tidak tersedia */
    }
  }

  /// Aktifkan mic browser → host. Gagal → kembalikan pesan error.
  async enableMic(): Promise<string | null> {
    if (this.micEnabled) return null;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true },
        video: false,
      });
      const track = stream.getAudioTracks()[0];
      if (!track) throw new Error('track mic tidak ada');
      // addTrack menempel ke transceiver audio sendrecv yang sudah ada
      // (dibuat saat negotiate()), jadi TIDAK perlu offer baru. RTP mic
      // langsung mengalir di m-line yang sudah disepakati sejak awal.
      this.pc?.addTrack(track, stream);
      this.micStream = stream;
      this.micEnabled = true;
      return null;
    } catch {
      return 'Izin mikrofon ditolak atau mic tidak tersedia.';
    }
  }

  async disableMic() {
    if (!this.micEnabled) return;
    this.micEnabled = false;
    for (const t of this.micStream?.getTracks() ?? []) t.stop();
    this.micStream = undefined;
  }

  stop() {
    if (this.stopped) return;
    this.stopped = true;
    void this.disableMic();
    this.input?.close();
    this.pc?.close();
    this.ws?.close();
    this.onPhase('ended');
  }
}
