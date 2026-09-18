import { receiverH264Level, offerWithH264Level } from './video_negotiation';
import { WallpaperTransfer } from './wallpaper_transfer';
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

  quality(q: number): Uint8Array {
    const b = new Uint8Array(8);
    b[0] = 0x0a;
    b[1] = Math.max(0, Math.min(3, q | 0));
    return b;
  },

  bitrateMbps(mbps: number): Uint8Array {
    const b = new Uint8Array(8);
    const v = new DataView(b.buffer);
    b[0] = 0x0b;
    v.setUint16(1, Math.max(0, Math.min(50, mbps | 0)), true);
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
  desktopMode?: {device:string;requested:[number,number];observed:[number,number]|null;status:string}|null;
  cursorEmbedded?: boolean;
  inputGeometry?: {left:number;top:number;width:number;height:number}|null;
  hardware?: Record<string, unknown>;
  video?: {level:number;requested:number;applied:[number,number]|null;contentRect?:[number,number,number,number]|null;fpsLimit:number};
  displays: HostDisplay[];
  wanted: number;
  audio: { available: boolean; pipeline: string };
  micInput?: { available: boolean; route: string };
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
  inputBufferedBytes?:number;
  coalescedMoves?:number;
  jitterMs?:number;
  jitterBufferMs?:number;
  decodeMs?:number;
  recentLossPct?:number;
  framesDropped?:number;
  freezeCount?:number;
  codec: string;
  bytesReceived?: number;
  packetsReceived?: number;
  packetsLost?: number;
  framesReceived?: number;
  framesDecoded?: number;
  keyFramesDecoded?: number;
  pliCount?: number;
  nackCount?: number;
  videoState?: string;
  playerState?: string;
  playerSize?: string;
  playerFrames?: number;
  cursorState?: string;
  audioPlayerState?: string;
  audioBytesReceived?: number;
  audioEnergy?: number;
  noFrameWarning?: boolean;
}

export class RtcSession {
  private receiverLevel = '1f';
  setResolution(mode:'720p'|'1080p'|'native'){this.sendInput(new Uint8Array([0x0c,mode==='720p'?0:mode==='native'?2:1]));}
  private wallpaperTransfer = new WallpaperTransfer();
  requestWallpaper():Promise<string>{
    if(this.input?.readyState!=='open')return Promise.reject(Error('Saluran kontrol belum siap.'));
    return this.wallpaperTransfer.request(bytes=>this.sendInput(bytes));
  }
  cancelWallpaper(){this.wallpaperTransfer.cancel("Preview otomatis dinonaktifkan atau akun berubah.");}
  private ws?: WebSocket;
  private pc?: RTCPeerConnection;
  private input?: RTCDataChannel;
  private pendingAbsoluteMove?:Uint8Array;
  private coalescedMoves=0;
  private deviceId = '';
  private token = '';
  private hostId = '';
  private stopped = false;
  private recoveryAttempt = 0;
  private recovering = false;
  private audioTransceiver?: RTCRtpTransceiver;
  private micStream?: MediaStream;
  private micGeneration = 0;
  private micPending?: Promise<string | null>;
  private micUpdates: Promise<void> = Promise.resolve();

  private updateMicSender(sender: RTCRtpSender, track: MediaStreamTrack | null) {
    const update = this.micUpdates.catch(() => {}).then(() => sender.replaceTrack(track));
    this.micUpdates = update;
    return update;
  }
  private watchdog?: ReturnType<typeof setTimeout>;
  private noFrameWatchdog?: ReturnType<typeof setTimeout>;
  public noFrameWarning = false;
  private phase: RtcPhase | '' = '';
  private wsFailed = false;
  private messages: Promise<void> = Promise.resolve();

  /// Pesan kegagalan terakhir, siap ditampilkan ke pengguna. `null` bila tidak
  /// ada kesalahan. Padanan `RtcService.lastError` di sisi Flutter.
  lastError: string | null = null;

  onPhase: (phase: RtcPhase) => void = () => {};
  onTrack: (stream: MediaStream) => void = () => {};
  onAudioTrack: (stream: MediaStream) => void = () => {};
  onCursor:(cursor:{x:number;y:number;visible:boolean})=>void=()=>{};
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
  private lastVideoStatsId = "";
  private lastTiming?:{id:string;emitted:number;delay:number;frames:number;decode:number;received:number;lost:number};

  /// Satu-satunya jalan mengubah fase. Menangani watchdog secara terpusat
  /// supaya tidak ada transisi yang lupa mematikan atau menyalakannya.
  ///
  /// Watchdog diperlukan karena `App.tsx` menonaktifkan tombol Konek selama
  /// fase `pairing`/`negotiating`. Tanpa batas waktu, host yang tidak pernah
  /// menjawab membuat tombol mati selamanya — pengguna tidak punya jalan
  /// keluar selain memuat ulang halaman. Flutter sudah menutup lubang ini
  /// (watchdog 20 detik di `rtc_service.dart`); web belum.
  private setPhase(next: RtcPhase, message?: string) {
    if (['ended', 'error', 'rejected', 'host-busy', 'peer-offline'].includes(next)) {
      this.closeTransport();
    }
    this.phase = next;
    if (message !== undefined) this.lastError = message;

    const menggantung = next === 'pairing' || next === 'negotiating';
    if (menggantung) {
      this.armWatchdog();
    } else {
      this.clearWatchdog();
      // Fase terminal yang bukan `error` berarti bukan kegagalan — bersihkan
      // pesan lama supaya UI tidak menampilkan sisa galat dari percobaan lalu.
      if (next !== 'error' && message === undefined) this.lastError = null;
    }

    if (next === 'connected') {
      this.armNoFrameWatchdog();
    } else {
      this.clearNoFrameWatchdog();
      this.noFrameWarning = false;
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

  private armNoFrameWatchdog() {
    this.clearNoFrameWatchdog();
    this.noFrameWatchdog = setTimeout(() => {
      this.noFrameWatchdog = undefined;
      if (this.stopped || this.phase !== 'connected') return;
      if (this.lastFrames <= 0) {
        this.noFrameWarning = true;
      }
    }, 10_000);
  }

  private clearNoFrameWatchdog() {
    if (this.noFrameWatchdog === undefined) return;
    clearTimeout(this.noFrameWatchdog);
    this.noFrameWatchdog = undefined;
  }

  /// Gagal dengan pesan yang bisa ditampilkan. Padanan `_fail()` di Flutter.
  private fail(message: string) {
    this.setPhase('error', message);
  }

  async start(jwt: string, hostId: string, pin: string) {
    this.hostId = hostId.replace(/[\s-]/g, '');
    this.deviceId = `web-${crypto.randomUUID()}`;
    this.wsFailed = false;
    this.token = await signalToken(jwt, this.deviceId);
    if (this.stopped) return;

    this.setPhase('pairing');
    const ws = new WebSocket(
      `${WS_URL}?id=${this.deviceId}&role=client&token=${encodeURIComponent(this.token)}`,
    );
    this.ws = ws;

    ws.onopen = () => {
      if (this.stopped) return;
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
    // WebSocket menjaga urutan pesan, bukan selesainya operasi async.
    // Kandidat ICE harus menunggu setRemoteDescription dari jawaban selesai.
    ws.onmessage = (ev) => {
      this.messages = this.messages.then(async () => {
        if (!this.stopped) await this.handle(JSON.parse(ev.data as string));
      }).catch(() => {
        if (!this.stopped) this.fail('Negosiasi WebRTC gagal. Coba hubungkan ulang.');
      });
    };
  }

  private send(m: SignalMessage) {
    this.ws?.send(JSON.stringify(m));
  }

  private async handle(m: SignalMessage) {
    if (['pair-response', 'answer', 'ice', 'bye'].includes(m.type) && m.from !== this.hostId) return;
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
        // Rem pairing server (hub.js) mengirim 'pair-terkunci' beserta alasan
        // dan sisa tunggu; 'host-sibuk' disimpan sebagai alias legacy supaya
        // client lama tetap paham bila berbicara dengan worker lama.
        if (m.error === 'pair-terkunci' || m.error === 'host-sibuk') {
          const retry = (m as { retry_in?: number }).retry_in;
          this.setPhase(
            'host-busy',
            retry && retry > 0
              ? `PC sedang dikendalikan sesi lain. Server mengunci pairing sementara — coba lagi dalam ${retry} detik.`
              : undefined,
          );
        }
        return;
    }
  }

  private async negotiate() {
    const iceServers: RTCIceServer[] = [
      { urls: ['stun:stun.cloudflare.com:3478'] },
    ];
    const turnServers = await turnIce(this.deviceId, this.token);
    if (this.stopped) return;
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
    // kecuali ke host. Dengan sendrecv, sender.replaceTrack(track mic) cukup menempel
    // ke transceiver yang sudah ada: tidak ada offer kedua, tidak ada
    // sesi yang dirombak (host membangun Session baru untuk setiap offer).
    this.audioTransceiver = pc.addTransceiver('audio', { direction: 'sendrecv' });
    this.input = pc.createDataChannel('input');
    this.input.binaryType = 'arraybuffer';
    this.input.bufferedAmountLowThreshold=512;
    this.input.onbufferedamountlow=()=>this.flushAbsoluteMove();
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
          this.wallpaperTransfer.receive(data);
          if(data.type==='cursor' && Number.isFinite(data.x) && Number.isFinite(data.y) && data.x>=0 && data.x<=1 && data.y>=0 && data.y<=1 && typeof data.visible==='boolean')this.onCursor(data);
          if (data.type === 'meta') {
            if(JSON.stringify([data.inputGeometry,data.video?.applied,data.video?.contentRect])!==JSON.stringify([this.meta?.inputGeometry,this.meta?.video?.applied,this.meta?.video?.contentRect]))this.pendingAbsoluteMove=undefined;
            this.meta = data as HostMeta;
            this.onMeta(this.meta);
          }
        } catch {
          /* meta tidak valid — abaikan */
        }
      }
    };

    pc.onicecandidate = (ev) => {
      if (this.stopped || !ev.candidate) return;
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
      if (this.stopped) return;
      const stream = ev.streams[0] ?? new MediaStream([ev.track]);
      if (ev.track.kind === 'video') {
        // Optional browser hint, not a guarantee or a measured latency.
        try {if(ev.receiver && 'jitterBufferTarget' in ev.receiver)(ev.receiver as RTCRtpReceiver & {jitterBufferTarget:number}).jitterBufferTarget=40;}catch{/* unsupported browser */}
        this.onTrack(stream);
      }
      else if (ev.track.kind === 'audio') this.onAudioTrack(stream);
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

    this.receiverLevel=await receiverH264Level();
    if(this.stopped)return;
    const offer = await pc.createOffer();
    try{await pc.setLocalDescription({...offer,sdp:offerWithH264Level(offer.sdp||'',this.receiverLevel)});}
    catch{this.receiverLevel='1f';await pc.setLocalDescription(offer);}
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
      await pc.setLocalDescription({...offer,sdp:offerWithH264Level(offer.sdp||'',this.receiverLevel)});
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

  private flushAbsoluteMove(){
    if(this.meta?.inputGeometry===null){this.pendingAbsoluteMove=undefined;return;}
    if(this.pendingAbsoluteMove&&this.input?.readyState==='open'&&this.input.bufferedAmount<=1024){
      this.input.send(this.pendingAbsoluteMove.slice().buffer);this.pendingAbsoluteMove=undefined;
    }
  }
  sendInput(event: Uint8Array) {
    if(this.meta?.inputGeometry===null)this.pendingAbsoluteMove=undefined;
    if(this.meta?.inputGeometry===null && (event[0]===1||event[0]===2||event[0]===4||(event[0]===3&&event[2]===1))){this.pendingAbsoluteMove=undefined;return;}
    const dc=this.input;if(dc?.readyState!=='open')return;
    // Only replace absolute movement that has NOT entered SCTP. Buttons,
    // releases, keys and relative deltas keep their reliable ordering.
    if(event[0]===2){
      if(dc.bufferedAmount>1024){if(this.pendingAbsoluteMove)this.coalescedMoves++;this.pendingAbsoluteMove=event.slice();return;}
      if(this.pendingAbsoluteMove)this.coalescedMoves++;
      this.pendingAbsoluteMove=undefined;
    }else if(this.pendingAbsoluteMove&&(event[0]===1||event[0]===3||event[0]===4)){
      dc.send(this.pendingAbsoluteMove.slice().buffer);this.pendingAbsoluteMove=undefined;
    }
    dc.send(event.slice().buffer);
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

  /// 0x0A VIDEO_QUALITY — preset kualitas (0=auto 1=medium 2=high 3=ultra)
  setQuality(q: number) {
    this.sendInput(InputCodec.quality(q));
  }

  /// 0x0B VIDEO_BITRATE — target bitrate Mbps (0=auto)
  setBitrate(mbps: number) {
    this.sendInput(InputCodec.bitrateMbps(mbps));
  }

  /// Baca statistik koneksi (resolusi, fps, bitrate, RTT, loss, codec).
  /// Laju dihitung dari delta sejak panggilan sebelumnya — panggil berkala
  /// (mis. tiap detik) agar angkanya stabil. Null bila PC belum siap.
  async readStats(): Promise<SessionStats | null> {
    const pc = this.pc;
    if (!pc || pc.connectionState !== 'connected') return null;
    let stats: SessionStats = {
      width: 0, height: 0, fps: 0, mbps: 0, rttMs: 0, lossPct: 0,
      codec: '—', videoState: 'Belum ada laporan RTP video',
    };
    try {
      const report = await pc.getStats();
      let rttMs = 0;
      // RTX/FEC bukan video utama. Jangan menimpa statistik H264 dengan
      // laporan repair/track kosong yang kebetulan muncul terakhir.
      const primary = Array.from(report.values())
        .map(s => s as unknown as Record<string, unknown>)
        .filter(x => x.type === 'inbound-rtp' && (x.kind === 'video' || x.mediaType === 'video'))
        .filter(x => !/\/(rtx|red|ulpfec|flexfec)/i.test(String(report.get(String(x.codecId))?.mimeType ?? '')))
        .sort((a, b) => Number(b.bytesReceived ?? 0) - Number(a.bytesReceived ?? 0))[0];
      for (const s of report.values() as Iterable<RTCStats>) {
        const x = s as unknown as Record<string, unknown>;
        if (primary && x.id === primary.id && x.type === 'inbound-rtp') {
          const now = performance.now();
          const bytes = Number(x.bytesReceived ?? 0);
          const frames = typeof x.framesDecoded === 'number' ? x.framesDecoded : undefined;
          if (this.lastVideoStatsId !== String(x.id)) {
            this.lastBytes = -1; this.lastFrames = -1; this.lastAtMs = 0;
            this.lastVideoStatsId = String(x.id);
          }
          const dt = this.lastAtMs > 0 ? (now - this.lastAtMs) / 1000 : 0;
          const mbps =
            this.lastBytes >= 0 && dt > 0.2
              ? Math.max(0, ((bytes - this.lastBytes) * 8) / dt / 1e6)
              : 0;
          const fps =
            frames !== undefined && this.lastFrames >= 0 && dt > 0.2
              ? Math.max(0, (frames - this.lastFrames) / dt)
              : 0;
          this.lastBytes = bytes;
          this.lastFrames = frames ?? -1;
          this.lastAtMs = now;
          const lost = Math.max(0, Number(x.packetsLost ?? 0));
          const recv = Number(x.packetsReceived ?? 0);
          const timing={id:String(x.id),emitted:Number(x.jitterBufferEmittedCount),delay:Number(x.jitterBufferDelay),frames:Number(x.framesDecoded),decode:Number(x.totalDecodeTime),received:recv,lost};
          const previous=this.lastTiming?.id===timing.id?this.lastTiming:undefined;
          const average=(total:number,count:number,oldTotal?:number,oldCount?:number)=>{
            if(oldTotal===undefined||oldCount===undefined||!Number.isFinite(total)||!Number.isFinite(count)||!Number.isFinite(oldTotal)||!Number.isFinite(oldCount)||count<=oldCount||total<oldTotal)return undefined;
            return (total-oldTotal)/(count-oldCount)*1000;
          };
          const jitterBufferMs=average(timing.delay,timing.emitted,previous?.delay,previous?.emitted);
          const decodeMs=average(timing.decode,timing.frames,previous?.decode,previous?.frames);
          const lostDelta=previous?Math.max(0,lost-previous.lost):0,recvDelta=previous?recv-previous.received:0;
          const recentLossPct=previous&&recvDelta>=0&&recvDelta+lostDelta>0?lostDelta/(recvDelta+lostDelta)*100:undefined;
          this.lastTiming=timing;
          const codec = report.get(String(x.codecId)) as { sdpFmtpLine?: string; mimeType?: string } | undefined;
          const fmt = String(codec?.sdpFmtpLine ?? '');
          const profile = /profile-level-id=([0-9a-f]{6})/i.exec(fmt)?.[1] ?? '';
          const codecName = String(codec?.mimeType ?? '').replace('video/', '');
          stats = {
            width: Number(x.frameWidth ?? 0),
            height: Number(x.frameHeight ?? 0),
            fps,
            mbps,
            rttMs: 0,
            lossPct: recv + lost > 0 ? (lost / (recv + lost)) * 100 : 0,
            jitterMs:typeof x.jitter==='number'&&Number.isFinite(x.jitter)&&x.jitter>=0?x.jitter*1000:undefined,
            jitterBufferMs,decodeMs,recentLossPct,
            framesDropped:typeof x.framesDropped==='number'?x.framesDropped:undefined,
            freezeCount:typeof x.freezeCount==='number'?x.freezeCount:undefined,
            codec: `${codecName || '—'}${profile ? ` (${profile})` : ''}`,
            bytesReceived: bytes, packetsReceived: recv, packetsLost: lost,
            framesReceived: typeof x.framesReceived === 'number' ? x.framesReceived : undefined,
            framesDecoded: frames,
            keyFramesDecoded: typeof x.keyFramesDecoded === 'number' ? x.keyFramesDecoded : undefined,
            pliCount: typeof x.pliCount === 'number' ? x.pliCount : undefined,
            nackCount: typeof x.nackCount === 'number' ? x.nackCount : undefined,
            videoState: frames === undefined ? 'Penghitung decode tidak tersedia; periksa pemutar'
              : typeof x.keyFramesDecoded === 'number' && x.keyFramesDecoded > frames ? 'Statistik decode tidak konsisten; periksa pemutar'
              : frames > 0 ? 'Frame sudah didecode; periksa tampilan jika masih hitam'
              : bytes > 0 ? 'Data video diterima, belum ada frame terdecode'
              : 'Belum tercatat payload video diterima',

          };
        } else if (x.type === 'candidate-pair' && (x.nominated || x.selected === true)) {
          if (x.state === 'succeeded' && typeof x.currentRoundTripTime === 'number') {
            rttMs = x.currentRoundTripTime * 1000;
          }
        }
      }
      if (stats) {
        stats.rttMs = rttMs;
        stats.inputBufferedBytes=this.input?.bufferedAmount;
        stats.coalescedMoves=this.coalescedMoves;
        const audioReports = Array.from(report.values()).map(s => s as unknown as Record<string, unknown>).filter(x => x.type === 'inbound-rtp' && (x.kind === 'audio' || x.mediaType === 'audio'));
        stats.audioBytesReceived = audioReports.reduce((sum, x) => sum + Number(x.bytesReceived ?? 0), 0);
        const energy = audioReports.filter(x => typeof x.totalAudioEnergy === 'number');
        if (energy.length) stats.audioEnergy = energy.reduce((sum, x) => sum + Number(x.totalAudioEnergy), 0);
        if (stats.width > 0 && stats.height > 0) {
          this.clearNoFrameWatchdog();
          this.noFrameWarning = false;
        }
        stats.noFrameWarning = this.noFrameWarning;
      }
      return stats;
    } catch {
      return null;
    }
  }

  /// Mute receiver secara lokal, tanpa mengubah SDP atau memutus mic sender.
  /// Mengubah transceiver.direction tanpa renegosiasi tidak membisukan audio.
  async setAudioEnabled(on: boolean) {
    if (this.audioTransceiver?.receiver.track) this.audioTransceiver.receiver.track.enabled = on;
  }

  /// Aktifkan mic browser → host. Gagal → kembalikan pesan error.
  enableMic(): Promise<string | null> {
    if (this.meta?.micInput?.available === false) return Promise.resolve('Input mic virtual belum tersedia di PC. Pasang virtual audio cable dengan izin kamu, lalu pilih recording endpoint-nya di aplikasi PC.');
    if (this.micEnabled) return Promise.resolve(null);
    if (this.micPending) return this.micPending;
    const pending = this.startMic(++this.micGeneration);
    this.micPending = pending;
    void pending.finally(() => { if (this.micPending === pending) this.micPending = undefined; });
    return pending;
  }

  private async startMic(generation: number): Promise<string | null> {
    const pc = this.pc;
    const sender = this.audioTransceiver?.sender;
    if (this.stopped || !pc || !sender) return 'Sesi audio belum siap.';
    let stream: MediaStream | undefined;
    const current = () => !this.stopped && this.pc === pc && this.micGeneration === generation;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true }, video: false,
      });
      const track = stream.getAudioTracks()[0];
      if (!track) throw new Error('track mic tidak ada');
      if (!current()) {
        stream.getTracks().forEach(t => t.stop());
        return 'Aktivasi mikrofon dibatalkan.';
      }
      this.micStream = stream;
      // Reuse the already-negotiated sendrecv sender. addTrack can allocate
      // another m-line after disable/re-enable and would need renegotiation.
      await this.updateMicSender(sender, track);
      if (!current()) {
        stream.getTracks().forEach(t => t.stop());
        return 'Aktivasi mikrofon dibatalkan.';
      }
      this.micEnabled = true;
      return null;
    } catch {
      stream?.getTracks().forEach(t => t.stop());
      if (this.micStream === stream) this.micStream = undefined;
      return 'Izin mikrofon ditolak, mic tidak tersedia, atau pengiriman mic gagal.';
    }
  }

  async disableMic() {
    ++this.micGeneration; // Also cancel a pending getUserMedia permission prompt.
    this.micPending = undefined;
    this.micEnabled = false;
    for (const t of this.micStream?.getTracks() ?? []) t.stop();
    this.micStream = undefined;
    const sender = this.audioTransceiver?.sender;
    if (sender?.replaceTrack) {
      try { await this.updateMicSender(sender, null); } catch { /* transport closed */ }
    }
  }

  private closeTransport() {
    if (this.stopped) return;
    this.stopped = true;
    this.clearWatchdog();
    this.clearNoFrameWatchdog();
    this.noFrameWarning = false;
    void this.disableMic();
    if (this.ws?.readyState === WebSocket.OPEN && this.hostId) {
      try { this.send({ type: 'bye', to: this.hostId }); } catch { /* socket sudah putus */ }
    }
    this.pendingAbsoluteMove=undefined;
    this.input?.close();
    this.pc?.close();
    this.ws?.close();
  }

  stop() {
    this.wallpaperTransfer.cancel();
    if (this.stopped) return;
    this.setPhase('ended');
  }
}
