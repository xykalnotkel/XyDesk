import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {transformWithOxc} from 'vite';
const {code}=await transformWithOxc(readFileSync(new URL('../src/session_fullscreen.ts',import.meta.url),'utf8').replace(/^export /gm,'')+'\nexports.api={enterSessionFullscreen,leaveSessionFullscreen};','session_fullscreen.ts');
function api(document){const exports={};vm.runInNewContext(code,{exports,document});return exports.api;}
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
