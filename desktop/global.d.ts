export {};

// Tipe kontrak IPC renderer ↔ proses utama Electron (lihat electron/main.cjs).
// Status mengikuti serialisasi camelCase dari host/src/control.rs.

declare global {
  interface SessionPayload {
    clientId: string;
    /** Nama perangkat pengendali, dilaporkan sendiri lewat pesan `pair`.
     *  `null`/`undefined` untuk client yang belum mengirimnya. */
    clientName?: string | null;
    /** "android" | "ios" | "windows" | "linux" | "macos" | "web" | ... */
    clientPlatform?: string | null;
    startedAtMs: number;
    durationMs: number;
  }

  interface VideoPayload {
    framesSent: number;
    fps: number;
    nvenc: boolean;
    /** 'nvenc' | 'openh264' | 'test-pattern' — label encoder aktif. */
    encoder?: string;
    /** Latensi pipeline host (capture -> tulis RTP), rata-rata EMA dalam ms. */
    latencyMs?: number;
    latencyMaxMs?: number;
  }

  interface AudioPayload {
    captureAvailable: boolean;
    pipeline: string;
    micAvailable: boolean;
    micPipeline: string;
    outputs: number;
    /** Volume master perangkat output default, 0.0-1.0 (bisa null). */
    volume: number | null;
  }

  interface DisplayPayload {
    index: number;
    name: string;
    width: number;
    height: number;
  }

  interface DisplaysPayload {
    list: DisplayPayload[];
    /** Indeks monitor yang dipakai sesi berikutnya. */
    wanted: number;
  }

  interface StatusPayload {
    state: 'starting' | 'connecting' | 'ready' | 'streaming' | 'error';
    engine?: boolean;
    deviceId: string | null;
    password: string | null;
    signalingUrl?: string | null;
    startedAtMs?: number;
    uptimeMs?: number;
    session: SessionPayload | null;
    video?: VideoPayload;
    audio?: AudioPayload;
    displays?: DisplaysPayload;
    targetBitrateBps?: number;
    lastError?: string | null;
  }

  interface ActionPayload {
    ok: boolean;
    error?: string | null;
    password?: string | null;
    stopped?: boolean | null;
  }

  interface InfoPayload {
    appVersion: string;
    signalingHttp: string;
    platform: string;
    packaged: boolean;
  }

  interface LogEntry {
    t: number;
    line: string;
  }

  /** Identitas pengguna yang boleh dilihat renderer — hasil publicUser() Worker. */
  interface AuthUserPayload {
    id: string;
    email: string;
    name: string | null;
    picture: string | null;
  }

  /**
   * Status login. SENGAJA tidak punya field token: token sesi hanya hidup di
   * proses utama (lihat electron/auth.cjs), jadi renderer tidak punya cara
   * memintanya, apalagi membocorkannya ke DOM atau log.
   */
  interface AuthSessionPayload {
    masuk: boolean;
    user: AuthUserPayload | null;
    metode?: 'google' | 'email' | null;
    /** exp JWT dalam detik epoch; null bila tidak terbaca. */
    exp: number | null;
    /** false bila OS tidak menyediakan enkripsi, jadi sesi tidak bertahan restart. */
    tersimpan: boolean;
  }

  /** Hasil percobaan login: gagal dilaporkan sebagai data, bukan exception. */
  interface AuthResultPayload {
    ok: boolean;
    sesi?: AuthSessionPayload;
    /** Kode mesin dari Worker, mis. 'wrong-otp', 'invalid_grant', 'cooldown'. */
    error?: string;
    /** Kalimat siap tampil untuk kode di atas. */
    message?: string;
    /** Sisa waktu tunggu bila ada: resend_in / retry_in (detik). */
    detail?: Record<string, unknown> | null;
  }

  interface Window {
    xydesk?: {
      getStatus(): Promise<StatusPayload>;
      runAction(req: {
        action: string;
        password?: string;
        /** aksi `display-select` */
        index?: number;
        /** aksi `audio-volume`, 0.0-1.0 */
        volume?: number;
        /** aksi `video-bitrate`, Mbps */
        bitrateMbps?: number;
      }): Promise<ActionPayload>;
      getLogs(): Promise<LogEntry[]>;
      getInfo(): Promise<InfoPayload>;
      getAutostart(): Promise<boolean>;
      setAutostart(enable: boolean): Promise<{ ok: boolean; enabled?: boolean; error?: string }>;
      restartEngine(): Promise<{ ok: boolean; restarted?: boolean }>;
      /** Tulis baris pendek ke tooltip tray + judul jendela. */
      setHint?(hint: string): Promise<{ ok: boolean }>;
      // ── Login ──
      authSession(): Promise<AuthSessionPayload>;
      /** Buka browser sistem untuk Google; code ditangkap di loopback oleh proses utama. */
      authGoogle(): Promise<AuthResultPayload>;
      authEmailRequest(email: string, name?: string): Promise<AuthResultPayload>;
      authEmailVerify(email: string, otp: string, name?: string): Promise<AuthResultPayload>;
      authLogout(): Promise<AuthResultPayload>;
    };
  }
}

