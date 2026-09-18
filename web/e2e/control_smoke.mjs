// React production handlers + real canvas MediaStream; transport is stubbed.
// No Windows input injection, signaling or Android device is exercised here.
import {createServer} from 'vite';
import {chromium} from 'playwright';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const root = new URL('../', import.meta.url).pathname;
const server = await createServer({root, configFile:false, oxc:{jsx:{runtime:'automatic'}}, server:{host:'127.0.0.1',port:4177}, plugins:[{
 name:'local-control-fixture', enforce:'pre',
 transform(source,id){
  if(id.endsWith('/src/App.tsx')) return source+'\nexport {ConnectScreen};';
  if(id.endsWith('/src/rtc.ts'))return source+`
RtcSession.prototype.start = async function() {
 window.__inputs=[];
 this.onPhase?.('connected');
 const c=document.createElement('canvas'); c.width=1280; c.height=592;
 const ctx=c.getContext('2d'); ctx.fillStyle='#273446';ctx.fillRect(0,0,1280,592);
 ctx.fillStyle='white';ctx.font='36px sans-serif';ctx.fillText('Uji kontrol sintetis — bukan desktop Windows',80,280);
 this.onTrack?.(c.captureStream(15));
};
RtcSession.prototype.sendInput=function(b){window.__inputs.push(Array.from(b));};
RtcSession.prototype.readStats=async function(){return null;};
RtcSession.prototype.stop=function(){};
`;
 },
 configureServer(s){s.middlewares.use('/control-fixture',(_q,r)=>{r.setHeader('content-type','text/html');r.end(`<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div id="root"></div><script type="module">import React from '/node_modules/.vite/deps/react.js';import client from'/node_modules/.vite/deps/react-dom_client.js';import{ConnectScreen}from'/src/App.tsx';import'/src/style.css';client.createRoot(document.getElementById('root')).render(React.createElement(ConnectScreen,{ensureToken:async()=>'fixture',accountName:''}));</script></body></html>`);});}
}]});
await server.listen();
const browser = await chromium.launch({headless:true,args:['--no-sandbox']});
const checks=[];
try{
 for(const viewport of [{width:390,height:844},{width:844,height:390}]){
  const context=await browser.newContext({viewport,isMobile:true,hasTouch:true});const page=await context.newPage();page.setDefaultTimeout(10000);console.log('viewport',viewport);
  const errors=[];page.on('pageerror',e=>{errors.push(e.message);console.error(e.message);});page.on('console',m=>{if(m.type()==='error')console.error(m.text());});
  await page.goto('http://127.0.0.1:4177/control-fixture');
  await page.locator('input').nth(0).fill('123456789');await page.locator('input').nth(1).fill('fixture');
  await page.getByRole('button',{name:'Konek sekarang',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('video')?.videoWidth===1280);
  await page.waitForFunction(()=>document.fullscreenElement?.className==='video-surface');
  console.log('video loaded');await page.locator('.remote-control-cursor').waitFor({state:'visible'});
  assert.equal(await page.getByRole('button',{name:'Mode trackpad',exact:true}).getAttribute('aria-pressed'),'true');
  const cdp=await context.newCDPSession(page);
  const touch=async(type,points)=>{return cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points.map(([id,x,y])=>({id,x,y}))});};
  const x=viewport.width*.30,y=viewport.height*.5;
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,x,y]]);await touch('touchMove',[[1,x+35,y+8]]);await touch('touchEnd',[]);
  let inputs=await page.evaluate(()=>window.__inputs);
  assert.ok(inputs.some(b=>b[0]===2));assert.equal(inputs.filter(b=>b[0]===3).length,0);
  const arrow=await page.locator('.remote-control-cursor').boundingBox();assert.ok(arrow.x>viewport.width*.5-2);
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,x,y]]);await touch('touchEnd',[]);
  inputs=await page.evaluate(()=>window.__inputs);assert.deepEqual(inputs.filter(b=>b[0]===3).map(b=>b.slice(0,3)),[[3,0,1],[3,0,0]]);
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,x,y]]);await touch('touchCancel',[]);
  assert.equal((await page.evaluate(()=>window.__inputs)).filter(b=>b[0]===3).length,0);
  // Native pointer capture on the hold button + second finger on video.
  const hold=await page.getByRole('button',{name:'Klik kiri',exact:true}).boundingBox();
  const hx=hold.x+hold.width/2,hy=hold.y+hold.height/2;
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,hx,hy]]);await touch('touchStart',[[1,hx,hy],[2,x,y]]);
  await touch('touchMove',[[1,hx,hy],[2,x+30,y]]);await touch('touchEnd',[[1,hx,hy]]);await touch('touchEnd',[]);
  inputs=await page.evaluate(()=>window.__inputs);assert.deepEqual(inputs.filter(b=>b[0]===3).map(b=>b.slice(0,3)),[[3,0,1],[3,0,0]]);
  assert.ok(inputs.some(b=>b[0]===2));
  assert.equal(await page.locator('.remote-input-area').evaluate(e=>getComputedStyle(e).touchAction),'none');
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,x,y]]);await touch('touchStart',[[1,x,y],[2,x+45,y]]);
  await touch('touchMove',[[1,x,y+20],[2,x+45,y+20]]);await touch('touchEnd',[]);
  inputs=await page.evaluate(()=>window.__inputs);assert.ok(inputs.some(b=>b[0]===4));assert.equal(inputs.filter(b=>b[0]===3).length,0);
  await page.getByRole('button',{name:'Mode trackpad',exact:true}).click();
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,x,y]]);await touch('touchEnd',[]);
  inputs=await page.evaluate(()=>window.__inputs);assert.equal(inputs[0][0],2);
  assert.deepEqual(inputs.filter(b=>b[0]===3).map(b=>b.slice(0,3)),[[3,0,1],[3,0,0]]);
  assert.ok(Math.abs((inputs[0][1]+inputs[0][2]*256)/65535-.30)<.005);
  await page.getByRole('button',{name:'Keluar layar penuh',exact:true}).click();
  await page.getByRole('button',{name:'Layar penuh',exact:true}).click();
  await page.waitForFunction(()=>document.fullscreenElement?.className==='video-surface');
  assert.equal(await page.locator('.remote-control-cursor').isVisible(),true);
  await page.getByRole('button',{name:'Keluar layar penuh',exact:true}).click();
  assert.deepEqual(errors,[]);
  checks.push({viewport,defaultTrackpad:true,arrowVisible:true,swipe:true,tap:true,cancelNoClick:true,holdAndDrag:true,twoFingerScroll:true,directPositionBeforeClick:true,connectFullscreen:true,nativeFullscreenCursor:true,pageErrors:errors});
  if(viewport.width===844)await page.screenshot({path:new URL('../../docs/qa/geometry-web-2026-09-18.png',import.meta.url).pathname});
  await context.close();
 }
 writeFileSync(new URL('../../docs/qa/geometry-web-2026-09-18.json',import.meta.url),JSON.stringify({result:'PASS',boundary:'Real React handlers, Chromium CDP touch events, local canvas stream; stubbed RtcSession transport, not Windows/Android injection',checks},null,2)+'\n');
 console.log(JSON.stringify(checks));
}finally{await browser.close();await server.close();}
