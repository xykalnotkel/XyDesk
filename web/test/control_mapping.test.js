import test from 'node:test';import assert from 'node:assert/strict';import vm from 'node:vm';import {readFileSync} from 'node:fs';import {transformWithOxc} from 'vite';
let source=readFileSync(new URL('../src/rtc.ts',import.meta.url),'utf8').replace(/^import \{([^}]+)\} from '\.\/api';/m,'const {$1}=api;').replace(/^export /gm,'');let {code}=await transformWithOxc(source+'\nexports.InputCodec=InputCodec;','rtc.ts');let rtc={};vm.runInNewContext(code,{exports:rtc,api:{},TextEncoder,TextDecoder,performance});
let pointerSource=readFileSync(new URL('../src/remote_pointer.ts',import.meta.url),'utf8').replace(/^export /gm,'');let pointerCode=await transformWithOxc(pointerSource+'\nexports.canonicalKey=canonicalKey;','pointer.ts');const pointerExports={};vm.runInNewContext(pointerCode.code,{exports:pointerExports});
source=readFileSync(new URL('../src/control_mapping.tsx',import.meta.url),'utf8').split('export function CustomControlMapping')[0].replace(/^import .*$/gm,'').replace(/^export /gm,'');({code}=await transformWithOxc(source+'\nexports.api={MappingHolds,normalizeMappings};','control_mapping.tsx'));let exports={};vm.runInNewContext(code,{exports,InputCodec:rtc.InputCodec,canonicalKey:pointerExports.canonicalKey});const {MappingHolds,normalizeMappings}=exports.api;
const key={id:'w',label:'W',kind:'key',code:87,x:50,y:50,size:56};
test('mapping sanitizes bounds, duplicate ids, unknown action and max count',()=>{const m=normalizeMappings([{...key,x:999,y:-9,size:999},key,{...key,id:'bad',kind:'xxx'}]);assert.equal(m.length,1);assert.equal(m[0].x,100);assert.equal(m[0].y,0);assert.equal(m[0].size,120);assert.equal(normalizeMappings(Array.from({length:30},(_,i)=>({...key,id:String(i)}))).length,24);});
test('multiple touches on same mapped key retain hold until final release',()=>{const events=[];const h=new MappingHolds(b=>events.push(Array.from(b)));h.down('a',key);h.down('b',key);h.up('a');assert.equal(events.length,1);h.up('b');assert.equal(events.length,2);assert.deepEqual(events.map(b=>[b[0],b[1],b[3]]),[[5,87,1],[5,87,0]]);});
test('mapping reset releases keys/buttons once; wheel has no stuck hold',()=>{const events=[];const h=new MappingHolds(b=>events.push(Array.from(b)));h.down('a',key);h.down('b',{...key,kind:'mouse',code:0});h.down('c',{...key,kind:'scroll',code:-120});h.reset();h.reset();assert.equal(events.length,5);assert.equal(events.filter(x=>x[0]===4).length,1);assert.equal(events.filter(x=>x[0]===3&&x[2]===0).length,1);});
test('shortcut presses modifier before key, releases reverse, and shares held modifier',()=>{
 const events=[];const h=new MappingHolds(b=>events.push([b[1]|b[2]<<8,b[3]]));
 const combo=normalizeMappings([{...key,kind:'chord',keys:[67,17,17,999]}])[0];
 h.down('ctrl',{...key,code:17});h.down('shortcut',combo);h.up('shortcut');
 assert.deepEqual(events,[[162,1],[67,1],[67,0]]);h.up('ctrl');assert.deepEqual(events.at(-1),[162,0]);
});
test('side mouse buttons and horizontal wheel serialize correct axis',()=>{
 const events=[];const h=new MappingHolds(b=>events.push(Array.from(b)));
 const mouse=normalizeMappings([{...key,kind:'mouse',code:4}])[0];h.down('mouse',mouse);h.up('mouse');
 h.down('wheel',{...key,kind:'scrollX',code:120});
 assert.deepEqual(events.slice(0,2).map(b=>[b[0],b[1],b[2]]),[[3,4,1],[3,4,0]]);assert.deepEqual(events[2].slice(0,5),[4,120,0,0,0]);
});
