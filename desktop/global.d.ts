export {};

// Tipe kontrak IPC renderer ↔ proses utama Electron / Tauri bridge.
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
    /** Backend capture aktif: hasil pengukuran watchdog, bukan preferensi. */
    captureBackend?: string;
    /** Total frame sejak engine mulai — bukti backend benar menghasilkan piksel. */
    framesCaptured?: number;
    /** Benar bila host jalan di RDP session — penyebab #1 hitam di lab Actions */
    isRdpSession?: boolean;
    /** Status virtual display driver seperti AnyDesk — driver-first (IddCx) untuk headless/RDP */
    virtualDisplay?: {
      needed: boolean;
      installed: boolean;
      isAdmin: boolean;
      /** true bila adapternya sudah ada di dxgi / PnP (bukan hanya SERVICE terpasang) */
      hasVirtualDisplay?: boolean;
      /** indeks monitor virtual bila ada, null bila belum dibuat */
      virtualIndex?: number | null;
      /** backend capture aktif: 'virtual-display-driver' | 'dxgi-duplication' | 'wgc' | 'gdi' */
      backend?: string | null;
      /** snapshot displays untuk build UI selector */
      displays?: DisplayPayload[] | null;
    };
    /** Status virtual mic driver — biar denyut di Recording */
    virtualMic?: {
      needed: boolean;
      installed: boolean;
      hasVirtualInput: boolean;
      hasVirtualOutput: boolean;
      renderTarget: string;
    };
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
    /** `win32` di Windows (kontrak warisan Electron), nama OS di tempat lain. */
    platform: string;
    /** Arsitektur proses: `x86_64` / `aarch64` (dipakai pemilih aset update). */
    arch: string;
    packaged: boolean;
    signalingWs: string;
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

  /** Hasil `check_update`: manifest resmi vs versi berjalan. */
  interface UpdateStatusPayload {
    currentVersion: string;
    latestVersion: string;
    latestBuild: number;
    updateAvailable: boolean;
    notes: string[];
    assetName: string | null;
    assetBytes: number | null;
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
        /** aksi `video-bitrate`, Mbps — 0=Auto */
        bitrateMbps?: number;
        /** aksi `video-quality`: auto/medium/high/ultra */
        quality?: string;
        /** aksi `driver-install` */
        driverType?: string;
        /** aksi `virtual-display-create` */
        width?: number;
        height?: number;
        count?: number;
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
      // ── Pembaruan aplikasi ──
      /** Bandingkan versi berjalan dengan manifest rilis resmi. */
      checkUpdate(): Promise<UpdateStatusPayload>;
      /** Unduh + verifikasi installer; resolve = path berkas terverifikasi. */
      downloadUpdate(): Promise<string>;
      /**
       * Jalankan installer lalu keluar. Janjinya TIDAK PERNAH resolve —
       * proses mengakhiri dirinya sendiri setelah installer lahir.
       */
      installUpdate(path: string): Promise<void>;
      // ── Driver Management (1-Click) ──
      checkDriversStatus?(): Promise<{
        vdd_installed: boolean;
        audio_installed: boolean;
        is_admin: boolean;
        can_install: boolean;
      }>;
      installDriver?(driverType: string): Promise<string>;
    };
  }
}
