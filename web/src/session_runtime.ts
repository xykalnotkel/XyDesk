import type {Position, Rect} from './remote_pointer';

export const SESSION_UI_REVISION = 'pointer-v2';

// Balik panah di tepi supaya seluruh bentuknya tidak jatuh di luar surface.
// Hotspot tetap pada posisi perintah, bukan digeser menjauh dari tepi gambar.
export function cursorLayout(box: Rect, image: Rect | null, pos: Position) {
  const r = image ?? box;
  const x = r.left - box.left + pos.x * r.width;
  const y = r.top - box.top + pos.y * r.height;
  const flipX = x > box.width - 36;
  const flipY = y > box.height - 48;
  return { left: x - (flipX ? 33 : 3), top: y - (flipY ? 45 : 3), flipX, flipY, ready: !!image };
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
