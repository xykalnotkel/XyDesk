import {validPreviewJpeg} from './preview_jpeg';
export const MAX_PREVIEW_URL = 350000;
/** Ordered chunks from the authenticated session, never a caller-supplied URL. */
export class WallpaperTransfer {
  private pending: {id:number;chunks:string[];total:number;size:number;resolve:(v:string)=>void;reject:(e:Error)=>void;timer:ReturnType<typeof setTimeout>}|null=null;
  request(send:(bytes:Uint8Array)=>void):Promise<string>{
    if(this.pending)return Promise.reject(Error('Preview masih diproses.'));
    return new Promise((resolve,reject)=>{
      const id=crypto.getRandomValues(new Uint32Array(1))[0];
      const timer=setTimeout(()=>this.cancel('Host belum mendukung preview wallpaper atau permintaan habis waktu.'),15000);
      this.pending={id,chunks:[],total:0,size:0,resolve,reject,timer};
      const b=new Uint8Array(5);b[0]=0x0d;new DataView(b.buffer).setUint32(1,id,true);
      try{send(b);}catch{this.cancel('Saluran preview belum tersedia.');}
    });
  }
  receive(data:unknown){
    const p=this.pending;if(!p||!data||typeof data!=='object')return;
    const d=data as Record<string,unknown>;if(d.id!==p.id)return;
    if(d.type==='wallpaper-error'){this.cancel('Wallpaper lokal tidak tersedia, terlalu besar, atau diminta terlalu cepat. Preview lama dipertahankan.');return;}
    if(d.type!=='wallpaper')return;
    if(!Number.isInteger(d.total)||Number(d.total)<1||Number(d.total)>22||d.index!==p.chunks.length||(p.total!==0&&p.total!==d.total)||typeof d.data!=='string'||d.data.length>16384||! /^[A-Za-z0-9+/]+={0,2}$/.test(d.data)) {this.cancel('Data preview tidak valid.');return;}
    p.total=Number(d.total);p.size+=d.data.length;
    if(p.size+23>MAX_PREVIEW_URL){this.cancel('Preview melebihi batas.');return;}
    p.chunks.push(d.data);
    if(p.chunks.length===p.total){
      const encoded=p.chunks.join('');
      try{const raw=atob(encoded);if(!validPreviewJpeg(raw))throw Error();}
      catch{this.cancel('Format preview tidak valid.');return;}
      clearTimeout(p.timer);this.pending=null;p.resolve('data:image/jpeg;base64,'+encoded);
    }
  }
  cancel(message='Sesi berakhir sebelum preview diterima.'){
    const p=this.pending;this.pending=null;if(p){clearTimeout(p.timer);p.reject(Error(message));}
  }
}
