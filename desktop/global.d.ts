export interface StatusPayload {
  engine: boolean;
  version?: string;
  uptimeMs?: number;
  signalingUrl?: string;
  framesCaptured?: number;
  captureBackend?: string;
  lastError?: string;
  isRdpSession?: boolean;
  session?: {
    peerId?: string;
    clientId?: string;
    state?: string;
    codec?: string;
    fps?: number;
    latencyMs?: number;
    rttMs?: number;
    bitrateKbps?: number;
    packetLossPct?: number;
    qualityPreset?: string;
    controlEnabled?: boolean;
    audioInputEnabled?: boolean;
    audioLoopbackEnabled?: boolean;
  };
  video?: {
    pipeline?: string;
    adapterName?: string;
    activePreset?: string;
    configuredBitrateKbps?: number;
    targetBitrateKbps?: number;
    fps?: number;
    encoderType?: string;
    autoBitrate?: boolean;
    fecEnabled?: boolean;
    smoothTier?: string;
    hwAcceleration?: boolean;
  };
  displays?: {
    list?: Array<{
      id: string;
      name: string;
      primary: boolean;
      resolution: string;
    }>;
    activeId?: string;
  };
  virtualDisplay?: {
    installed: boolean;
    needed: boolean;
    isAdmin: boolean;
  };
}

export interface InfoPayload {
  name: string;
  version: string;
  platform: string;
  build: number;
  serverUrl?: string;
  osName?: string;
  deviceLabel?: string;
}

export interface ConfigPayload {
  port: number;
  signalingUrl: string;
  stunServers: string[];
  turnServers?: Array<{
    urls: string[];
    username?: string;
    credential?: string;
  }>;
  resolution: string;
  fps: number;
  bitrateKbps: number;
  autoBitrate: boolean;
  encoder: string;
  enableAudio: boolean;
  enableAudioInput: boolean;
  enableVirtualDisplay: boolean;
  authRequired: boolean;
  pairingPin?: string;
  autoStart: boolean;
  minimizeToTray: boolean;
  turnOffDisplayOnDisconnect: boolean;
  lockOnDisconnect: boolean;
}

export interface AuthSessionPayload {
  token: string;
  user: {
    id: string;
    email: string;
    name?: string;
    avatarUrl?: string;
    tier?: string;
  };
  expiresAt: number;
}

export interface AuthResultPayload {
  ok: boolean;
  session?: AuthSessionPayload;
  code?: string;
  message?: string;
  retryAfterSec?: number;
}

export interface UpdateChannelInfo {
  version: string;
  build: number;
  releasedAt?: string;
  notes?: string;
  downloadUrl: string;
  sha256?: string;
  sizeBytes?: number;
  mandatory?: boolean;
}

export interface UpdateStatusPayload {
  hasUpdate: boolean;
  currentVersion: string;
  currentBuild: number;
  target?: UpdateChannelInfo;
  checkedAt: string;
  error?: string;
}

declare global {
  interface Window {
    xydesk?: {
      getStatus(): Promise<StatusPayload>;
      getInfo(): Promise<InfoPayload>;
      getConfig(): Promise<ConfigPayload>;
      saveConfig(cfg: ConfigPayload): Promise<{ ok: boolean }>;
      stopSession(): Promise<{ ok: boolean }>;
      showWindow(): Promise<void>;
      hideWindow(): Promise<void>;
      // ── Autentikasi ──
      authGoogleLogin(): Promise<AuthResultPayload>;
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
