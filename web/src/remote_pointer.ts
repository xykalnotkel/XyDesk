export type Rect = { left: number; top: number; width: number; height: number };
export type Position = { x: number; y: number };
export type PointerOutput =
  | { type: 'move'; x: number; y: number }
  | { type: 'button'; button: number; down: boolean }
  | { type: 'scroll'; dy: number };

// Koordinat harus mengikuti gambar object-fit:contain, bukan pita hitam.
export function imageRect(box: Rect, width: number, height: number): Rect | null {
  if (!(width > 0 && height > 0 && box.width > 0 && box.height > 0)) return null;
  const scale = Math.min(box.width / width, box.height / height);
  const w = width * scale, h = height * scale;
  return { left: box.left + (box.width - w) / 2, top: box.top + (box.height - h) / 2, width: w, height: h };
}
const clamp = (v: number) => Math.max(0, Math.min(1, v));
type Contact = Position & { startX: number; startY: number; at: number; moved: boolean; trackpad: boolean; button: number };

// Penunjuk lokal = posisi perintah terakhir, bukan telemetri kursor Windows.
// Trackpad memakai delta jari untuk memindahkan posisi absolut yang sama
// dengan panah lokal: tidak bergantung akselerasi mouse Windows/resolusi RDP.
export class RemotePointer {
  cursor: Position = { x: 0.5, y: 0.5 };
  private contacts = new Map<number, Contact>();
  private buttons = new Set<number>();
  private buttonOwners = new Map<number, Set<string>>();
  private multi = false;
  constructor(private rect: () => Rect | null, private emit: (event: PointerOutput) => void) {}
  button(button: number, down: boolean, owner = 'pointer') {
    const owners = this.buttonOwners.get(button) ?? new Set<string>();
    const wasDown = owners.size > 0;
    if (down) owners.add(owner); else owners.delete(owner);
    if (owners.size) { this.buttonOwners.set(button, owners); this.buttons.add(button); }
    else { this.buttonOwners.delete(button); this.buttons.delete(button); }
    if (wasDown !== (owners.size > 0)) this.emit({ type: 'button', button, down: owners.size > 0 });
  }
  private position(x: number, y: number) {
    this.cursor = { x: clamp(x), y: clamp(y) };
    this.emit({ type: 'move', ...this.cursor });
  }
  sync() { this.position(this.cursor.x, this.cursor.y); }
  down(id: number, x: number, y: number, button: number, trackpad: boolean, at: number): boolean {
    const r = this.rect();
    if (!r || this.contacts.has(id)) return false;
    if (!trackpad && (this.contacts.size > 0 || x < r.left || y < r.top || x > r.left + r.width || y > r.top + r.height)) return false;
    if (this.contacts.size === 0) this.multi = false;
    this.contacts.set(id, { x, y, startX: x, startY: y, at, moved: false, trackpad, button });
    if (trackpad) {
      if (this.contacts.size > 1) this.multi = true;
      else this.position(this.cursor.x, this.cursor.y);
    } else {
      this.position((x - r.left) / r.width, (y - r.top) / r.height);
      this.button(button, true);
    }
    return true;
  }
  move(id: number, x: number, y: number, trackpad: boolean, sens: number, reverseScroll: boolean) {
    const r = this.rect();
    if (!r) return;
    const p = this.contacts.get(id);
    if (!p) {
      if (!trackpad && x >= r.left && x <= r.left + r.width && y >= r.top && y <= r.top + r.height) {
        this.position((x - r.left) / r.width, (y - r.top) / r.height);
      }
      return;
    }
    const dx = x - p.x, dy = y - p.y;
    p.x = x; p.y = y;
    if (Math.hypot(x - p.startX, y - p.startY) > 6) p.moved = true;
    if (!p.trackpad) this.position((x - r.left) / r.width, (y - r.top) / r.height);
    else if (this.multi) {
      if (this.contacts.size === 2 && dy !== 0) this.emit({ type: 'scroll', dy: Math.round(dy * (reverseScroll ? -1 : 1)) });
    } else this.position(this.cursor.x + dx * sens / r.width, this.cursor.y + dy * sens / r.height);
  }
  up(id: number, cancelled: boolean, tapClick: boolean, at: number) {
    const p = this.contacts.get(id);
    if (!p) return;
    this.contacts.delete(id);
    if (!p.trackpad) this.button(p.button, false);
    else if (!cancelled && !this.multi && !p.moved && tapClick && at - p.at < 300 && this.buttons.size === 0) {
      this.position(this.cursor.x, this.cursor.y);
      this.button(0, true); this.button(0, false);
    }
    if (this.contacts.size === 0) this.multi = false;
  }
  reset() {
    for (const b of this.buttons) this.emit({type:'button',button:b,down:false});
    this.buttons.clear(); this.buttonOwners.clear();
    this.contacts.clear(); this.multi = false;
  }
}
