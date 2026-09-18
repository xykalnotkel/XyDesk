import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {transformWithOxc} from 'vite';
const {code}=await transformWithOxc(readFileSync(new URL('../src/session_fullscreen.ts',import.meta.url),'utf8').replace(/^export /gm,'')+'\nexports.api={enterSessionFullscreen,leaveSessionFullscreen,enterSessionLandscape};','session_fullscreen.ts');
function api(document,screen={orientation:{}}){const exports={};vm.runInNewContext(code,{exports,document,screen});return exports.api;}
test('fullscreen dipanggil segera pada surface sesi, bukan dokumen/video saja',async()=>{
 const document={fullscreenElement:null};let called=false;const surface={requestFullscreen:async()=>{called=true;document.fullscreenElement=surface;}};
 const pending=api(document).enterSessionFullscreen(surface);assert.equal(called,true);assert.equal(await pending,true);
});
test('penolakan dan API tidak tersedia mengembalikan fallback tanpa error',async()=>{
 const a=api({fullscreenElement:null});assert.equal(await a.enterSessionFullscreen({}),false);assert.equal(await a.enterSessionFullscreen({requestFullscreen:async()=>{throw Error('denied');}}),false);
});
test('keluar hanya fullscreen milik sesi',async()=>{
 let exits=0;const surface={};const document={fullscreenElement:{},exitFullscreen:async()=>{exits++;}};const a=api(document);
 await a.leaveSessionFullscreen(surface);assert.equal(exits,0);document.fullscreenElement=surface;await a.leaveSessionFullscreen(surface);assert.equal(exits,1);
});

test('Konek meminta fullscreen langsung lalu landscape, penolakan tetap aman',async()=>{
 const document={fullscreenElement:null},calls=[];const surface={requestFullscreen:async()=>{calls.push('fullscreen');document.fullscreenElement=surface;}};
 const a=api(document,{orientation:{lock:async mode=>calls.push(mode)}});const p=a.enterSessionLandscape(surface);assert.deepEqual(calls,['fullscreen']);assert.equal(await p,'landscape');assert.deepEqual(calls,['fullscreen','landscape']);
 const denied=api(document,{orientation:{lock:async()=>{throw Error('unsupported')}}});assert.equal(await denied.enterSessionLandscape(surface),'fullscreen');
});
test('cancelled connect does not lock orientation and exits its fullscreen',async()=>{
 let resolve,locked=0,exits=0;const document={fullscreenElement:null,exitFullscreen:async()=>{exits++;document.fullscreenElement=null;}};
 const surface={requestFullscreen:()=>new Promise(r=>{resolve=()=>{document.fullscreenElement=surface;r();};})};
 const p=api(document,{orientation:{lock:async()=>locked++}}).enterSessionLandscape(surface,()=>false);resolve();assert.equal(await p,'cancelled');assert.equal(locked,0);assert.equal(exits,1);
});
