import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {transformWithOxc} from 'vite';
const src=readFileSync(new URL('../src/session_runtime.ts',import.meta.url),'utf8').replace(/^import type .*$/gm,'').replace(/^export /gm,'')+'\nexports.api={cursorLayout,playRemoteAudio,newSessionFragment,isSessionFragment};';
const {code}=await transformWithOxc(src,'session_runtime.ts');const exports={};vm.runInNewContext(code,{exports});const {cursorLayout,playRemoteAudio,newSessionFragment,isSessionFragment}=exports.api;
test('panah tetap masuk viewport di keempat sudut; hotspot mengikuti koordinat',()=>{
 const box={left:0,top:0,width:390,height:844};
 for(const x of [0,.5,1])for(const y of [0,.5,1]){
  const p=cursorLayout(box,box,{x,y});
  assert.equal(p.left+(p.flipX?33:3),x*390);assert.equal(p.top+(p.flipY?45:3),y*844);
  assert.ok(p.left<390&&p.left+36>0&&p.top<844&&p.top+48>0);
  if(x===1)assert.equal(p.flipX,true);if(y===1)assert.equal(p.flipY,true);
 }
});
test('tanpa metadata video panah punya posisi fallback, bukan display:none',()=>{
 const p=cursorLayout({left:0,top:0,width:400,height:800},null,{x:.5,y:.5});assert.equal(p.ready,false);assert.equal(p.left,197);assert.equal(p.top,397);
});
test('audio benar-benar memanggil play, tidak mengganti stream yang sama',async()=>{
 let n=0;const stream={};const audio={srcObject:stream,play:async()=>{n++}};assert.equal(await playRemoteAudio(audio,stream),true);assert.equal(n,1);
 assert.equal(await playRemoteAudio({srcObject:null}),false);
 await assert.rejects(playRemoteAudio({srcObject:stream,play:async()=>{throw Error('NotAllowedError')}}),/NotAllowed/);
});
test('URL session acak 256 bit tidak membawa kredensial dan parser ketat',()=>{
 const random={getRandomValues:a=>{for(let i=0;i<a.length;i++)a[i]=i;return a;}};
 const h=newSessionFragment(random);assert.equal(h.length,73);assert.ok(isSessionFragment(h));assert.ok(isSessionFragment('#session'));assert.equal(isSessionFragment(h+'/x'),false);assert.equal(isSessionFragment('#session/password'),false);
});
