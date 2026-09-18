import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {transformWithOxc} from 'vite';
const {code} = await transformWithOxc(readFileSync(new URL('../src/remote_pointer.ts', import.meta.url), 'utf8').replace(/^export /gm, '') + '\nexports.api={imageRect,RemotePointer};', 'remote_pointer.ts');
const exports={}; vm.runInNewContext(code,{exports});
const {imageRect,RemotePointer}=exports.api;
const plain = x => JSON.parse(JSON.stringify(x));
function setup(){const events=[]; const r={left:0,top:100,width:400,height:200}; const p=new RemotePointer(()=>r,e=>events.push(plain(e)));return {p,events,r};}
test('contain letterbox portrait/landscape dan dimensi belum tersedia',()=>{
 assert.deepEqual(plain(imageRect({left:10,top:20,width:400,height:800},1280,640)),{left:10,top:320,width:400,height:200});
 assert.deepEqual(plain(imageRect({left:0,top:0,width:800,height:400},200,400)),{left:300,top:0,width:200,height:400});
 assert.equal(imageRect({left:0,top:0,width:400,height:800},0,0),null);
});
test('sentuh langsung mengirim posisi sebelum klik; pita hitam diabaikan',()=>{
 const {p,events}=setup(); assert.equal(p.down(1,200,50,0,false,0),false);assert.equal(events.length,0);
 p.down(1,100,150,0,false,1);p.up(1,false,true,20);
 assert.deepEqual(events,[{type:'move',x:.25,y:.25},{type:'button',button:0,down:true},{type:'button',button:0,down:false}]);
});
test('trackpad mempertahankan posisi antar sapuan, fraksi kecil tidak dibuang',()=>{
 const {p,events}=setup();p.down(1,10,20,0,true,0);
 for(let i=1;i<=40;i++)p.move(1,10+i*.25,20,true,1,false);
 p.up(1,false,true,100);assert.ok(Math.abs(p.cursor.x-.525)<1e-10);
 p.down(2,300,20,0,true,200);assert.ok(Math.abs(p.cursor.x-.525)<1e-10);
 assert.equal(events.filter(e=>e.type==='button').length,0);
});
test('tap kiri, cancel bukan klik, dua jari tanpa gerak bukan klik',()=>{
 const {p,events}=setup();p.down(1,0,0,0,true,0);p.up(1,false,true,100);
 assert.equal(events.filter(e=>e.type==='button').length,2);events.length=0;
 p.down(1,0,0,0,true,200);p.up(1,true,true,210);
 p.down(1,0,0,0,true,300);p.down(2,20,0,0,true,305);p.up(1,false,true,310);p.up(2,false,true,320);
 assert.equal(events.filter(e=>e.type==='button').length,0);
});
test('dua jari scroll tidak menggerakkan panah/klik setelah satu jari dilepas',()=>{
 const {p,events}=setup();p.down(1,10,10,0,true,0);p.down(2,30,10,0,true,1);events.length=0;
 p.move(1,10,30,true,1,false);p.up(1,false,true,10);p.move(2,50,30,true,1,false);p.up(2,false,true,20);
 assert.deepEqual(events,[{type:'scroll',dy:20}]);
});
test('drag: tombol ditahan, geser, reset melepas sekali dan tidak klik',()=>{
 const {p,events}=setup();p.button(0,true);p.down(1,10,10,0,true,0);p.move(1,90,10,true,1,false);p.up(1,false,true,100);p.reset();p.reset();
 assert.deepEqual(events.filter(e=>e.type==='button'),[{type:'button',button:0,down:true},{type:'button',button:0,down:false}]);
 assert.ok(events.some(e=>e.type==='move'&&e.x===.7));
});
test('clamp tepi gambar, cancel direct melepaskan tombol, reset menghapus gesture',()=>{
 const {p,events}=setup();p.down(1,100,150,1,false,0);p.move(1,900,-200,false,1,false);p.up(1,true,true,10);
 assert.deepEqual(plain(p.cursor),{x:1,y:0});assert.deepEqual(events.at(-1),{type:'button',button:1,down:false});
 p.down(2,0,0,0,true,100);p.reset();events.length=0;p.up(2,false,true,110);assert.equal(events.length,0);
});
test('HUD dan mapping yang menahan tombol sama tidak saling melepas',()=>{const {p,events}=setup();p.button(0,true,'hud');p.button(0,true,'mapping');p.button(0,false,'hud');assert.deepEqual(events,[{type:'button',button:0,down:true}]);p.button(0,false,'mapping');assert.deepEqual(events.at(-1),{type:'button',button:0,down:false});p.button(0,true,'mapping');p.reset();assert.deepEqual(events.at(-1),{type:'button',button:0,down:false});});
test('sensitivitas trackpad mengubah delta sesuai pilihan pengguna',()=>{const slow=setup(),fast=setup();for(const t of [slow,fast])t.p.down(1,100,150,0,true,0);slow.p.move(1,110,150,true,.2,false);fast.p.move(1,110,150,true,4,false);assert.ok(Math.abs(slow.p.cursor.x-.505)<1e-9);assert.ok(Math.abs(fast.p.cursor.x-.6)<1e-9);});
