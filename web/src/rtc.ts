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
    // Audio forward (host → browser): m-line audio di offer; host mengisi
    // track Opus bila WASAPI aktif.
    this.audioTransceiver = pc.addTransceiver('audio', { direction: 'recvonly' });
    this.input = pc.createDataChannel('input');
    this.input.onmessage = (ev) => {
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

  /// 0x07 DISPLAY_SELECT — pindah monitor host.
  selectDisplay(index: number) {
    const b = new Uint8Array(8);
    b[0] = 0x07;
    b[1] = Math.max(0, Math.min(255, index | 0));
    this.sendInput(b);
  }

  /// Aktif/nonaktifkan pemutaran audio host (transceiver direction).
  async setAudioEnabled(on: boolean) {
    if (!this.audioTransceiver) return;
    try {
      this.audioTransceiver.direction = on ? 'recvonly' : 'inactive';
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
