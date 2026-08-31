export {};

// Tipe kontrak IPC renderer ↔ proses utama Electron (lihat electron/main.cjs).
// Status mengikuti serialisasi camelCase dari host/src/control.rs.

declare global {
  interface SessionPayload {
    clientId: string;
    startedAtMs: number;
    durationMs: number;
  }

  interface VideoPayload {
    framesSent: number;
    fps: number;
    nvenc: boolean;
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
      runAction(req: { action: string; password?: string }): Promise<ActionPayload>;
      getLogs(): Promise<LogEntry[]>;
      getInfo(): Promise<InfoPayload>;
    };
  }
}

