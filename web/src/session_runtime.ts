import type {Position, Rect} from './remote_pointer';

export const SESSION_UI_REVISION = 'pointer-v2';

// Balik panah di tepi supaya seluruh bentuknya tidak jatuh di luar surface.
// Hotspot tetap pada posisi perintah, bukan digeser menjauh dari tepi gambar.
export function cursorLayout(box: Rect, image: Rect | null, pos: Position, size = 36) {
  const r = image ?? box;
  const x = r.left - box.left + pos.x * r.width;
  const y = r.top - box.top + pos.y * r.height;
  const width = Math.max(24, Math.min(96, size)), height=width*4/3;
  const tip=width/12;
  const flipX = x > box.width - width;
  const flipY = y > box.height - height;
  return { left: x - (flipX ? width-tip : tip), top: y - (flipY ? height-tip : tip), flipX, flipY, ready: !!image };
}

export async function playRemoteAudio(audio: HTMLAudioElement, stream?: MediaStream) {
  if (stream && audio.srcObject !== stream) audio.srcObject = stream;
  if (!audio.srcObject) return false;
  await audio.play();
  return true;
}

// ID tampilan saja, BUKAN kredensial atau tiket pemulihan sesi.
// Jangan memasukkan password, JWT, ID host, atau resume token ke URL.
export function newSessionFragment(random: Crypto = crypto): string {
  const bytes = random.getRandomValues(new Uint8Array(32));
  return '#session/' + Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
}
export function isSessionFragment(hash: string): boolean {
  return hash === '#session' || /^#session\/[0-9a-f]{64}$/.test(hash);
}
