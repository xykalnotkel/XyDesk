import test from 'node:test';import assert from 'node:assert/strict';import vm from 'node:vm';import {readFileSync} from 'node:fs';import {webcrypto} from 'node:crypto';import {transformWithOxc} from 'vite';
const src=['preview_jpeg.ts','wallpaper_transfer.ts','video_negotiation.ts'].map(n=>readFileSync(new URL('../src/'+n,import.meta.url),'utf8').replace(/^import .*$/gm,'').replace(/^export /gm,'')).join('\n');
const {code}=await transformWithOxc(src+'\nexports.api={validPreviewJpeg,WallpaperTransfer,offerWithH264Level,receiverH264Level};','preview.ts');
function setup(navigator={}){const exports={};vm.runInNewContext(code,{exports,crypto:webcrypto,navigator,setTimeout,clearTimeout,atob,Uint8Array,DataView});return exports.api;}
test('ordered JPEG chunks assembled once; unrelated reply ignored; explicit errors and cancellation',async()=>{
 const {WallpaperTransfer}=setup(),t=new WallpaperTransfer();let id;
 const promise=t.request(b=>{id=new DataView(b.buffer).getUint32(1,true);assert.equal(b[0],13)});
 t.receive({type:'wallpaper-error',id:id+1});
 t.receive({type:'wallpaper',id,index:0,total:2,data:'/9j/wAARCACQAQADASIAAhEB'});t.receive({type:'wallpaper',id,index:1,total:2,data:'AxEB/9oADAMBAAIRAxEAPwD/2Q=='});
 assert.equal(await promise,'data:image/jpeg;base64,/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==');
 const failure=t.request(b=>id=new DataView(b.buffer).getUint32(1,true));t.receive({type:'wallpaper',id,index:1,total:2,data:'AAAA'});await assert.rejects(failure,/valid/);
 const cancelled=t.request(()=>{});t.cancel();await assert.rejects(cancelled,/berakhir/);
});
test('oversized transfers, repeated chunks and non-JPEG refused',async()=>{
 for(const patch of [{total:23},{data:'A'.repeat(16385)},{data:'https://x'},{data:'AAAA',total:1}]){
 const {WallpaperTransfer}=setup(),t=new WallpaperTransfer();let id;const p=t.request(b=>id=new DataView(b.buffer).getUint32(1,true));t.receive({type:'wallpaper',id,index:0,total:2,data:'AAAA',...patch});await assert.rejects(p);
 }
});
test('capability probe falls back honestly; only supported levels modify H264',async()=>{
 assert.equal(await setup().receiverH264Level(),'1f');
 const calls=[];const api=setup({mediaCapabilities:{decodingInfo:async c=>{calls.push(c.video.width);return {supported:c.video.width===1920};}}});
 assert.equal(await api.receiverH264Level(),'28');assert.deepEqual(calls,[4096,1920]);
 const s='a=fmtp:108 packetization-mode=1;profile-level-id=42e01f\r\n';assert.ok(api.offerWithH264Level(s,'28').includes('42e028'));assert.equal(api.offerWithH264Level(s,'ff'),s);
});

test('JPEG header bounds are identical on client/server and reject oversized decoded images',()=>{
 const server=readFileSync(new URL('../../cloudflare/src/preview_jpeg.js',import.meta.url),'utf8'),client=readFileSync(new URL('../src/preview_jpeg.ts',import.meta.url),'utf8');assert.equal(client.replace('raw:string','raw'),server);
 const {validPreviewJpeg}=setup(),raw=atob('/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==');assert.equal(validPreviewJpeg(raw),true);
 assert.equal(validPreviewJpeg(raw.slice(0,9)+'\x10\x00'+raw.slice(11)),false);
 assert.equal(validPreviewJpeg(raw.slice(0,7)+'\x08\x00'+raw.slice(9)),false);
 assert.equal(validPreviewJpeg(raw.slice(0,12)),false);assert.equal(validPreviewJpeg('\xff\xd8\xff\xd9'),false);
});
