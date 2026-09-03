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
    };
  }
}

