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
// Host contentRect is in encoded pixels. Ignore stale/invalid metadata,
// but never stretch the desktop or count the encoded padding as its content.
export type VideoGeometry={applied:[number,number]|null;contentRect?:[number,number,number,number]|null};
export function validContent(video:VideoGeometry|undefined,width:number,height:number):[number,number,number,number]|null {
 const r=video?.contentRect;
 if(!r||video?.applied?.[0]!==width||video?.applied?.[1]!==height||r.length!==4||!r.every(Number.isFinite))return null;
 return r[0]>=0&&r[1]>=0&&r[2]>=2&&r[3]>=2&&r[0]+r[2]<=width&&r[1]+r[3]<=height?r:null;
}
export function desktopRect(box:Rect,width:number,height:number,video?:VideoGeometry):Rect|null {
 const frame=imageRect(box,width,height);if(!frame)return null;
 const r=validContent(video,width,height);if(!r)return frame;
 return {left:frame.left+r[0]/width*frame.width,top:frame.top+r[1]/height*frame.height,width:r[2]/width*frame.width,height:r[3]/height*frame.height};
}
export function desktopToCanvas(x:number,y:number,width:number,height:number,video?:VideoGeometry):Position {
 const r=validContent(video,width,height);if(!r)return{x,y};
 return{x:(r[0]+Math.max(0,Math.min(1,x))*(r[2]-1))/(width-1),y:(r[1]+Math.max(0,Math.min(1,y))*(r[3]-1))/(height-1)};
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
  applyHostPosition(x:number,y:number){if(!this.contacts.size)this.cursor={x:clamp(x),y:clamp(y)};}
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

// Satu key-up dari keyboard virtual tidak boleh melepas tombol milik mapping
// atau keyboard fisik yang masih ditahan.
export function canonicalKey(vk:number){return vk===16?160:vk===17?162:vk===18?164:vk;}
export class KeyOwnership {
 private owners=new Map<number,Set<string>>();
 constructor(private emit:(vk:number,down:boolean)=>void){}
 set(vk:number,down:boolean,owner:string,repeat=false){
  vk=canonicalKey(vk);
  const sources=this.owners.get(vk)||new Set<string>(),was=sources.size>0;
  const own=sources.has(owner);
  if(down)sources.add(owner);else sources.delete(owner);
  if(sources.size)this.owners.set(vk,sources);else this.owners.delete(vk);
  if(was!==(sources.size>0)||(repeat&&down&&own))this.emit(vk,sources.size>0);
 }
 reset(){for(const vk of this.owners.keys())this.emit(vk,false);this.owners.clear();}
}
