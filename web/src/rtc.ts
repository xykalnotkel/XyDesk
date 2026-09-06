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
  | 'ended'
  /// Kegagalan nyata: signaling tidak terjangkau, host tidak menjawab sampai
  /// batas waktu, atau ICE gagal setelah semua percobaan pemulihan.
  ///
  /// Cermin dari `RtcPhase.error` di `lib/webrtc/rtc_service.dart`. Tanpa fase
  /// ini web tidak punya cara mengatakan "gagal" — yang ada hanya `ended`
  /// ("Sesi berakhir"), yang terdengar seperti akhir normal padahal bukan, dan
  /// layar menggantung tanpa tombol yang bisa diklik lagi.
  ///
  /// Pesan yang bisa ditampilkan ada di [`RtcSession.lastError`].
  | 'error';

/// Batas waktu pairing/negosiasi — SAMA DENGAN `lib/webrtc/rtc_service.dart`
/// (watchdog 20 detik) supaya dua platform gagal pada saat yang sama dengan
/// pesan yang sama.
const WATCHDOG_MS = 20_000;

/// Pesan saat ICE gagal setelah seluruh percobaan pemulihan habis.
///
/// Sengaja menyebut TURN, karena inilah sebab yang paling sering: dua
/// perangkat di belakang NAT simetris/CGNAT tidak bisa saling sapa langsung
/// dan hanya tersambung lewat penengah. Kalau TURN tidak terkonfigurasi di
/// server, sesi akan selalu berakhir di sini.
const PESAN_ICE_GAGAL =
  'Koneksi langsung gagal ditembus setelah beberapa percobaan. ' +
  'Ini biasanya terjadi bila kedua perangkat berada di jaringan yang ' +
  'membatasi (NAT simetris / CGNAT) dan server relay (TURN) tidak tersedia. ' +
  'Coba jaringan lain, atau minta operator mengisi secret TURN.';

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
  /** Label diri untuk panel host (pesan `pair`): browser + OS, mis.
   *  "Chrome di Windows". Host hanya MENAMPILKANNYA — tidak pernah
   *  memutuskan akses dari nilai ini. */
  name?: string;
  /** Selalu "web" untuk peramban; host memakainya untuk memilih label. */
  platform?: string;
}

/// Tebak "browser di OS" dari userAgent — tanpa izin, tanpa dependensi baru.
/// Tidak akurat itu boleh: nilainya cuma label di layar host.
function browserLabel(): string {
  const ua = typeof navigator === 'undefined' ? '' : navigator.userAgent;
  const browser = /Edg\//.test(ua)
    ? 'Edge'
    : /OPR\//.test(ua)
      ? 'Opera'
      : /Firefox\//.test(ua)
        ? 'Firefox'
        : /Chrome\//.test(ua)
          ? 'Chrome'
          : /Safari\//.test(ua)
            ? 'Safari'
            : 'Peramban web';
  const os = /Windows/.test(ua)
    ? 'Windows'
    : /Android/.test(ua)
      ? 'Android'
      : /iPhone|iPad|iPod/.test(ua)
        ? 'iOS'
        : /Mac OS X/.test(ua)
          ? 'macOS'
          : /Linux/.test(ua)
            ? 'Linux'
            : '';
  return os ? `${browser} di ${os}` : browser;
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
    let end = utf8.length;
    // Pemotongan HANYA bila teksnya kepanjangan. Sama seperti klien Dart:
    // membersihkan ekor walau tidak memotong akan menghapus karakter
    // terakhir yang sah dan membuat seluruh pesan ditolak penerima.
    if (end > 64 * 1024) {
      end = 64 * 1024;
      // Mundur berdasar byte pertama yang DIBUANG, bukan yang terakhir
      // diikutkan — lihat penjelasan di klien Dart.
      while (end > 0 && (utf8[end] & 0xc0) === 0x80) end--;
    }
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

/// Statistik sesi yang dibaca langsung dari koneksi (getStats).
/// Nilai bitrate/fps adalah laju sesaat — dihitung dari delta antar bacaan.
export interface SessionStats {
  width: number;
  height: number;
  fps: number;
  mbps: number;
  rttMs: number;
  lossPct: number;
  codec: string;
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
  private watchdog?: ReturnType<typeof setTimeout>;
  private phase: RtcPhase | '' = '';
  private wsFailed = false;

  /// Pesan kegagalan terakhir, siap ditampilkan ke pengguna. `null` bila tidak
  /// ada kesalahan. Padanan `RtcService.lastError` di sisi Flutter.
  lastError: string | null = null;

  onPhase: (phase: RtcPhase) => void = () => {};
  onTrack: (stream: MediaStream) => void = () => {};
  onAudioTrack: (stream: MediaStream) => void = () => {};
  onMeta: (meta: HostMeta) => void = () => {};
  /// Isi papan klip PC — balasan dari `requestClipboard()`.
  onClipboard: (text: string) => void = () => {};

  meta: HostMeta | null = null;
  micEnabled = false;
  /// Nama yang dilaporkan ke host pada pesan `pair`. Kalau kosong, label
  /// browser dipakai. Diisi dari App.tsx bila ada nama akun yang lebih berguna.
  selfName?: string;

  // Penanding delta untuk readStats(): byte & frame terakhir + waktu baca.
  private lastBytes = -1;
  private lastFrames = -1;
  private lastAtMs = 0;

  /// Satu-satunya jalan mengubah fase. Menangani watchdog secara terpusat
  /// supaya tidak ada transisi yang lupa mematikan atau menyalakannya.
  ///
  /// Watchdog diperlukan karena `App.tsx` menonaktifkan tombol Konek selama
  /// fase `pairing`/`negotiating`. Tanpa batas waktu, host yang tidak pernah
  /// menjawab membuat tombol mati selamanya — pengguna tidak punya jalan
  /// keluar selain memuat ulang halaman. Flutter sudah menutup lubang ini
  /// (watchdog 20 detik di `rtc_service.dart`); web belum.
  private setPhase(next: RtcPhase, message?: string) {
    this.phase = next;
    if (message !== undefined) this.lastError = message;

    const menggantung = next === 'pairing' || next === 'negotiating';
    if (menggantung) {
      this.armWatchdog();
    } else {
      this.clearWatchdog();
      // Fase terminal yang bukan `error` berarti bukan kegagalan — bersihkan
      // pesan lama supaya UI tidak menampilkan sisa galat dari percobaan lalu.
      if (next !== 'error') this.lastError = null;
    }
    this.onPhase(next);
  }

  private armWatchdog() {
    this.clearWatchdog();
    this.watchdog = setTimeout(() => {
      this.watchdog = undefined;
      if (this.stopped) return;
      if (this.phase !== 'pairing' && this.phase !== 'negotiating') return;
      const tahap = this.phase === 'pairing' ? 'merespons pairing' : 'menyelesaikan negosiasi';
      this.setPhase(
        'error',
        `Host tidak ${tahap} dalam ${WATCHDOG_MS / 1000} detik. ` +
          'Periksa XyDesk Host di PC masih berjalan, lalu coba lagi.',
      );
    }, WATCHDOG_MS);
  }

  private clearWatchdog() {
    if (this.watchdog === undefined) return;
    clearTimeout(this.watchdog);
    this.watchdog = undefined;
  }

  /// Gagal dengan pesan yang bisa ditampilkan. Padanan `_fail()` di Flutter.
  private fail(message: string) {
    this.setPhase('error', message);
  }

  async start(jwt: string, hostId: string, pin: string) {
    this.hostId = hostId.replace(/[\s-]/g, '');
    this.deviceId = `web-${Date.now() % 1000000}`;
    this.wsFailed = false;
    this.token = await signalToken(jwt, this.deviceId);

    this.setPhase('pairing');
    const ws = new WebSocket(
      `${WS_URL}?id=${this.deviceId}&role=client&token=${encodeURIComponent(this.token)}`,
    );
    this.ws = ws;

    ws.onopen = () => {
      this.send({ type: 'hello', to: this.deviceId, reason: 'client' });
      this.send({
        type: 'pair',
        to: this.hostId,
        pin,
        name: (this.selfName?.trim() || browserLabel()).slice(0, 48),
        platform: 'web',
      });
    };
    ws.onerror = () => {
      // Browser hanya memberi tahu "gagal", tanpa sebab — bisa DNS, TLS,
      // jaringan mati, atau CSP yang memblokir origin. `onclose` menyusul
      // segera setelah ini, jadi pesan di sana yang berbicara ke pengguna.
      this.wsFailed = true;
    };
    ws.onclose = (ev) => {
      if (this.stopped) return;
      if (this.phase === 'connected') {
        // Sesi sedang berjalan lalu soket putus — itu kegagalan, bukan akhir
        // yang rapi (akhir yang rapi lewat pesan `bye`).
        this.fail('Koneksi signaling terputus saat sesi berjalan.');
        return;
      }
      if (this.wsFailed || ev.code !== 1000) {
        this.fail(
          'Tidak dapat menghubungi server signaling. ' +
            'Periksa koneksi internet, lalu coba lagi.',
        );
        return;
      }
      this.setPhase('ended');
    };
    ws.onmessage = (ev) => void this.handle(JSON.parse(ev.data as string));
  }

  private send(m: SignalMessage) {
    this.ws?.send(JSON.stringify(m));
  }

  private async handle(m: SignalMessage) {
    switch (m.type) {
      case 'pair-response':
        if (!m.accepted) {
          // Host sengaja TIDAK mengirim sebab penolakan (biar respons pairing
          // tidak jadi oracle password). Dugaan paling umum disalin dari sisi
          // Flutter: sejak 3 Sep 2026 host membandingkan password PEKA-KASUS.
          return this.setPhase(
            'rejected',
            'Password ditolak host. Periksa huruf besar/kecil dan spasi di ujung ' +
              '— ketik ulang, jangan salin dari catatan yang sudah terkapitalisasi.',
          );
        }
        this.setPhase('negotiating');
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
        if (m.error === 'peer-offline') this.setPhase('peer-offline');
        // Host sibuk: sesi lain sedang berjalan — koneksi kedua ditolak
        // meski password benar (host melayani satu sesi pada satu waktu).
        if (m.error === 'host-sibuk') this.setPhase('host-busy');
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
        this.setPhase('connected');
      } else if (pc.connectionState === 'failed') {
        void this.recoverConnection();
      } else if (pc.connectionState === 'closed') {
        // Ditutup tanpa pesan `bye` = kegagalan, bukan akhir yang rapi.
        // Cermin dari `rtc_service.dart`: `if (!_stopped) _fail(...)`.
        if (!this.stopped) this.fail('Koneksi peer ditutup paksa.');
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
      this.fail(PESAN_ICE_GAGAL);
      return;
    }
    this.recovering = true;
    this.recoveryAttempt += 1;
    this.setPhase('negotiating');
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
      if (this.recoveryAttempt >= 2) this.fail(PESAN_ICE_GAGAL);
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

  /// Baca statistik koneksi (resolusi, fps, bitrate, RTT, loss, codec).
  /// Laju dihitung dari delta sejak panggilan sebelumnya — panggil berkala
  /// (mis. tiap detik) agar angkanya stabil. Null bila PC belum siap.
  async readStats(): Promise<SessionStats | null> {
    const pc = this.pc;
    if (!pc || pc.connectionState !== 'connected') return null;
    let stats: SessionStats | null = null;
    try {
      const report = await pc.getStats();
      let rttMs = 0;
      for (const s of report.values() as Iterable<RTCStats>) {
        const x = s as unknown as Record<string, unknown>;
        if (x.type === 'inbound-rtp' && (x.kind === 'video' || x.mediaType === 'video')) {
          const now = performance.now();
          const bytes = Number(x.bytesReceived ?? 0);
          const frames = Number(x.framesDecoded ?? 0);
          const dt = this.lastAtMs > 0 ? (now - this.lastAtMs) / 1000 : 0;
          const mbps =
            this.lastBytes >= 0 && dt > 0.2
              ? Math.max(0, ((bytes - this.lastBytes) * 8) / dt / 1e6)
              : 0;
          const fps =
            this.lastFrames >= 0 && dt > 0.2
              ? Math.max(0, (frames - this.lastFrames) / dt)
              : 0;
          this.lastBytes = bytes;
          this.lastFrames = frames;
          this.lastAtMs = now;
          const lost = Math.max(0, Number(x.packetsLost ?? 0));
          const recv = Number(x.packetsReceived ?? 0);
          const fmt = String(x.sdpFmtpsLine ?? '');
          const profile = /profile-level-id=(\w{4})/i.exec(fmt)?.[1] ?? '';
          const codecName = String(x.mimeType ?? '').replace('video/', '');
          stats = {
            width: Number(x.frameWidth ?? 0),
            height: Number(x.frameHeight ?? 0),
            fps,
            mbps,
            rttMs: 0,
            lossPct: recv + lost > 0 ? (lost / (recv + lost)) * 100 : 0,
            codec: `${codecName || '—'}${profile ? ` (${profile})` : ''}`,
          };
        } else if (x.type === 'candidate-pair' && (x.nominated || x.selected === true)) {
          if (x.state === 'succeeded' && typeof x.currentRoundTripTime === 'number') {
            rttMs = x.currentRoundTripTime * 1000;
          }
        }
      }
      if (stats) stats.rttMs = rttMs;
      return stats;
    } catch {
      return null;
    }
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
    this.setPhase('ended');
  }
}
