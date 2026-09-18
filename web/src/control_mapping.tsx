import {canonicalKey} from './remote_pointer';
import {useEffect,useRef,useState} from 'react';
import {InputCodec} from './rtc';
export type Mapping={id:string;label:string;kind:'key'|'mouse'|'scroll'|'scrollX'|'chord';code:number;keys?:number[];x:number;y:number;size:number};
const KEY='xydesk.mapping.v1';
const clamp=(n:number,min:number,max:number)=>Math.min(max,Math.max(min,n));
export function normalizeMappings(raw:unknown):Mapping[]{
 if(!Array.isArray(raw))return [];
 const ids=new Set<string>();return raw.slice(0,24).filter(x=>x&&typeof x.id==='string'&&x.id.length<=50&&!ids.has(x.id)&&ids.add(x.id)&&['key','mouse','scroll','scrollX','chord'].includes(x.kind)&&Number.isFinite(x.code)).map(x=>({id:x.id.slice(0,50),label:String(x.label||'?').slice(0,12),kind:x.kind,keys:x.kind==='chord'?chordKeys(x.keys):undefined,code:clamp(Math.round(x.code),x.kind.startsWith('scroll')?-120:0,x.kind==='key'?255:x.kind==='mouse'?4:120),x:clamp(Number(x.x)||0,0,100),y:clamp(Number(x.y)||0,0,100),size:clamp(Number(x.size)||56,36,120)}));
}
export function chordKeys(raw:unknown):number[]{
 if(!Array.isArray(raw))return [];
 const modifier=(n:number)=>[16,17,18,91,92,160,161,162,163,164,165].includes(n);
 return [...new Set(raw.filter(n=>Number.isInteger(n)&&n>0&&n<=255))].slice(0,6).sort((a,b)=>Number(modifier(b))-Number(modifier(a)));
}
export const KEY_OPTIONS:(number|string)[][]=[
 ...Array.from({length:26},(_,i)=>[65+i,String.fromCharCode(65+i)]),
 ...Array.from({length:10},(_,i)=>[48+i,String(i)]),
 ...Array.from({length:24},(_,i)=>[112+i,`F${i+1}`]),
 [32,'Spasi'],[13,'Enter'],[27,'Esc'],[9,'Tab'],[16,'Shift'],[17,'Ctrl'],[18,'Alt'],[91,'Windows'],[8,'Backspace'],[46,'Delete'],[37,'←'],[38,'↑'],[39,'→'],[40,'↓'],
 [36,'Home'],[35,'End'],[33,'Page Up'],[34,'Page Down'],[45,'Insert'],[20,'Caps Lock'],[144,'Num Lock'],[145,'Scroll Lock'],[19,'Pause'],[44,'Print Screen'],
 ...Array.from({length:10},(_,i)=>[96+i,`Numpad ${i}`]),[106,'Numpad ×'],[107,'Numpad +'],[109,'Numpad −'],[110,'Numpad .'],[111,'Numpad ÷'],
 [186,';'],[187,'='],[188,','],[189,'-'],[190,'.'],[191,'/'],[192,'`'],[219,'['],[220,'Backslash'],[221,']'],[222,"'"],
];
const defaults=()=>normalizeMappings([
 {id:'w',label:'W',kind:'key',code:87,x:14,y:52,size:52},{id:'a',label:'A',kind:'key',code:65,x:7,y:68,size:52},{id:'s',label:'S',kind:'key',code:83,x:14,y:68,size:52},{id:'d',label:'D',kind:'key',code:68,x:21,y:68,size:52},
 {id:'left',label:'Klik kiri',kind:'mouse',code:0,x:76,y:68,size:60},{id:'space',label:'Spasi',kind:'key',code:32,x:85,y:48,size:60},
]);
export class MappingHolds {
 private owners=new Map<string,Mapping>();private counts=new Map<string,number>();
 constructor(private send:(b:Uint8Array)=>void){}
 private actions(m:Mapping):Mapping[]{return (m.kind==='chord'?(m.keys||[]).map(code=>({...m,kind:'key' as const,code})): [m]).map(a=>a.kind==='key'?{...a,code:canonicalKey(a.code)}:a);}
 down(owner:string,m:Mapping){if(this.owners.has(owner))return;if(m.kind==='scroll'||m.kind==='scrollX'){this.send(InputCodec.scroll(m.kind==='scrollX'?m.code:0,m.kind==='scroll'?m.code:0));return;}this.owners.set(owner,m);for(const a of this.actions(m)){const key=a.kind+':'+a.code,n=this.counts.get(key)||0;this.counts.set(key,n+1);if(n===0)this.send(a.kind==='key'?InputCodec.key(a.code,true):InputCodec.mouseButton(a.code,true));}}
 up(owner:string){const m=this.owners.get(owner);if(!m)return;this.owners.delete(owner);for(const a of this.actions(m).reverse()){const key=a.kind+':'+a.code,n=(this.counts.get(key)||1)-1;if(n){this.counts.set(key,n);}else{this.counts.delete(key);this.send(a.kind==='key'?InputCodec.key(a.code,false):InputCodec.mouseButton(a.code,false));}}}
 reset(){for(const owner of [...this.owners.keys()])this.up(owner);}
}
export function CustomControlMapping({send}:{send:(b:Uint8Array)=>void}){
 const [landscape,setLandscape]=useState(()=>innerWidth>innerHeight);const orientation=landscape?'landscape':'portrait';
 const load=()=>{try{const raw=JSON.parse(localStorage.getItem(KEY)||'{}')[orientation];return Array.isArray(raw)?normalizeMappings(raw):null;}catch{return null;}};
 const [items,setItems]=useState<Mapping[]>(()=>{return load()??defaults();});
 const [edit,setEdit]=useState(false),[selected,setSelected]=useState('');const [inspector,setInspector]=useState(false);const selectedItem=items.find(x=>x.id===selected);
 const sendRef=useRef(send);sendRef.current=send;const holds=useRef<MappingHolds|null>(null);if(!holds.current)holds.current=new MappingHolds(b=>sendRef.current(b));
 const drag=useRef<{pointer:number;id:string;dx:number;dy:number}|null>(null);const [notice,setNotice]=useState('');
 useEffect(()=>{const media=matchMedia('(orientation: landscape)');const resize=()=>setLandscape(media.matches);media.addEventListener('change',resize);return()=>media.removeEventListener('change',resize);},[]);
 useEffect(()=>{holds.current!.reset();drag.current=null;setItems(load()??defaults());setSelected('');},[orientation]);
 useEffect(()=>{const reset=()=>holds.current!.reset();const visibility=()=>{if(document.hidden)reset();};window.addEventListener('blur',reset);document.addEventListener('visibilitychange',visibility);return()=>{reset();window.removeEventListener('blur',reset);document.removeEventListener('visibilitychange',visibility);};},[]);
 useEffect(()=>{holds.current!.reset();},[edit]);
 const save=()=>{try{const all=JSON.parse(localStorage.getItem(KEY)||'{}');all[orientation]=items;localStorage.setItem(KEY,JSON.stringify(all));setEdit(false);setNotice('Layout disimpan untuk '+orientation+'.');}catch{setNotice('Penyimpanan browser penuh atau tidak tersedia.');}};
 const update=(patch:Partial<Mapping>)=>setItems(old=>normalizeMappings(old.map(x=>x.id===selected?{...x,...patch}:x)));
 return <>
 <div className="mapping-tools" data-editing={edit} onPointerDown={e=>e.stopPropagation()}><button type="button" onClick={()=>{if(edit)save();else{setEdit(true);setInspector(false);}}}>{edit?'Simpan layout':'Atur tombol'}</button>{edit&&<button type="button" onClick={()=>setInspector(v=>!v)}>{inspector?'Tutup properti':'Properti tombol'}</button>}{notice&&<small role="status">{notice}</small>}</div>
 {items.map(m=><button key={m.id} type="button" aria-label={`Mapping ${m.label}`} className={`mapping-button${edit?' editing':''}${selected===m.id&&edit?' selected':''}`} style={{left:`clamp(calc(env(safe-area-inset-left) + ${m.size/2}px), ${m.x}%, calc(100% - env(safe-area-inset-right) - ${m.size/2}px))`,top:`clamp(calc(env(safe-area-inset-top) + ${m.size/2}px), ${m.y}%, calc(100% - env(safe-area-inset-bottom) - ${m.size/2}px))`,width:m.size,height:m.size}}
 onPointerDown={e=>{e.stopPropagation();e.preventDefault();e.currentTarget.setPointerCapture(e.pointerId);if(edit){setSelected(m.id);const rect=e.currentTarget.getBoundingClientRect();drag.current={pointer:e.pointerId,id:m.id,dx:e.clientX-rect.left-rect.width/2,dy:e.clientY-rect.top-rect.height/2};}else holds.current!.down(m.id+':'+e.pointerId,m);}}
 onPointerMove={e=>{e.stopPropagation();const d=drag.current;if(!edit||!d||d.pointer!==e.pointerId||d.id!==m.id)return;const r=e.currentTarget.closest('.video-surface')!.getBoundingClientRect();setItems(old=>old.map(x=>x.id===m.id?{...x,x:clamp((e.clientX-r.left-d.dx)/r.width*100,0,100),y:clamp((e.clientY-r.top-d.dy)/r.height*100,0,100)}:x));}}
 onPointerUp={e=>{e.stopPropagation();drag.current=null;holds.current!.up(m.id+':'+e.pointerId);}}
 onPointerCancel={e=>{drag.current=null;holds.current!.up(m.id+':'+e.pointerId);}}
 onLostPointerCapture={e=>{holds.current!.up(m.id+':'+e.pointerId);}} onContextMenu={e=>e.preventDefault()}>{m.label}</button>)}
 {edit&&inspector&&<aside className="mapping-editor" onPointerDown={e=>e.stopPropagation()} onWheel={e=>e.stopPropagation()}><strong>Edit layout · {orientation}</strong><p>Geser tombol ke posisi bebas. Saat mengedit, tombol tidak mengirim input ke PC.</p><button type="button" disabled={items.length>=24} onClick={()=>{const id=crypto.randomUUID();setItems(old=>[...old,{id,label:'E',kind:'key',code:69,x:50,y:50,size:56}]);setSelected(id);}}>Tambah tombol</button>
 {selectedItem&&<><label>Nama<input value={selectedItem.label} maxLength={12} onChange={e=>update({label:e.target.value})}/></label><label>Aksi<select value={selectedItem.kind} onChange={e=>update({kind:e.target.value as Mapping['kind'],code:e.target.value.startsWith('scroll')?120:e.target.value==='mouse'?0:69})}><option value="key">Keyboard</option><option value="mouse">Mouse</option><option value="scroll">Scroll vertikal</option><option value="scrollX">Scroll horizontal</option><option value="chord">Shortcut kombinasi</option></select></label>
 {selectedItem.kind==='key'?<label>Tombol<select value={selectedItem.code} onChange={e=>update({code:Number(e.target.value)})}>{KEY_OPTIONS.map(([v,t])=><option key={v} value={v}>{t}</option>)}</select></label>:selectedItem.kind==='chord'?<label>Tombol kombinasi (maks. 6)<select multiple size={6} value={(selectedItem.keys||[]).map(String)} onChange={e=>update({keys:chordKeys([...e.target.selectedOptions].map(x=>Number(x.value)))})}>{KEY_OPTIONS.map(([v,t])=><option key={v} value={v}>{t}</option>)}</select></label>:<label>Tombol<select value={selectedItem.code} onChange={e=>update({code:Number(e.target.value)})}>{(selectedItem.kind==='mouse'?[[0,'Kiri'],[1,'Kanan'],[2,'Tengah'],[3,'Samping kembali'],[4,'Samping maju']]:selectedItem.kind==='scrollX'?[[120,'Ke kanan'],[-120,'Ke kiri']]:[[120,'Ke atas'],[-120,'Ke bawah']]).map(([v,t])=><option key={v} value={v}>{t}</option>)}</select></label>}
 <label>Ukuran {selectedItem.size}px<input type="range" min="36" max="120" value={selectedItem.size} onChange={e=>update({size:Number(e.target.value)})}/></label><button type="button" onClick={()=>{setItems(old=>old.filter(x=>x.id!==selected));setSelected('');}}>Hapus tombol</button></>}
 <button type="button" onClick={()=>{holds.current!.reset();setItems(defaults());setSelected('');}}>Preset D-pad WASD + mouse</button><p>Untuk shortcut, tahan tombol Ctrl/Shift/Alt sambil menekan tombol lain. Layout tersimpan di browser ini, terpisah portrait/landscape.</p><button type="button" onClick={()=>{holds.current!.reset();setItems(defaults());setSelected('');}}>Pulihkan layout bawaan</button></aside>}
 </>;
}
