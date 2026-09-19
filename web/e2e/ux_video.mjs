// React production handlers + real canvas MediaStream; transport is stubbed.
// No Windows input injection, signaling or Android device is exercised here.
import {createServer} from 'vite';
import {chromium} from 'playwright';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const root = new URL('../', import.meta.url).pathname;
const server = await createServer({root, configFile:false, oxc:{jsx:{runtime:'automatic'}}, server:{host:'127.0.0.1',port:0}, plugins:[{
 name:'local-control-fixture', enforce:'pre',
 transform(source,id){
  if(id.endsWith('/src/App.tsx')) return source+'\nexport {ConnectScreen};';
  if(id.endsWith('/src/rtc.ts'))return source+`
RtcSession.prototype.start = async function() {
 window.__inputs=[];window.__fixtureSession=this;this.input={readyState:'open'};
 this.onPhase?.('pairing'); await new Promise(r=>setTimeout(r,600));
 this.onPhase?.('negotiating'); await new Promise(r=>setTimeout(r,300));
 this.onPhase?.('connected');
 const c=document.createElement('canvas'); c.width=1280; c.height=720;
 const ctx=c.getContext('2d'); ctx.fillStyle='black';ctx.fillRect(0,0,1280,720);ctx.fillStyle='#273446';ctx.fillRect(0,64,1280,592);
 ctx.fillStyle='white';ctx.font='36px sans-serif';ctx.fillText('Uji kontrol sintetis — bukan desktop Windows',80,280);
 this.onTrack?.(c.captureStream(15));
 const ac=new AudioContext();const dest=ac.createMediaStreamDestination();const osc=ac.createOscillator();osc.connect(dest);osc.start();
 this.onAudioTrack?.(dest.stream);
 this.onMeta?.(this.meta={desktopMode:{device:"fixture",requested:[1920,1080],observed:[2336,1080],status:"rejected"},cursorEmbedded:true,video:{applied:[1280,720],contentRect:[0,64,1280,592],level:51,requested:1,fpsLimit:30,fpsControl:true,fpsRequested:30},displays:[],wanted:0,audio:{available:true,pipeline:'fixture'},hardware:{hostname:'PC uji sintetis',cpu:'Fixture CPU',ram:'Fixture RAM'}});
 this.onMeta?.(this.meta={desktopMode:{device:"fixture",requested:[1920,1080],observed:[2336,1080],status:"rejected"},cursorEmbedded:true,video:{applied:[1280,720],contentRect:[0,64,1280,592],level:51,requested:1,fpsLimit:30,fpsControl:true,fpsRequested:30},displays:[],wanted:0,audio:{available:true,pipeline:'fixture'},hardware:{hostname:'PC uji sintetis',cpu:'Fixture CPU',ram:'Fixture RAM'}});

 window.__fixtureStartDone=(window.__fixtureStartDone||0)+1;
};
RtcSession.prototype.sendInput=function(b){
 window.__inputs.push(Array.from(b));
 if(b[0]===13){
  const id=new DataView(b.buffer,b.byteOffset,b.byteLength).getUint32(1,true),c=document.createElement('canvas');c.width=1920;c.height=1080;
  const ctx=c.getContext('2d');ctx.fillStyle='#245d45';ctx.fillRect(0,0,1920,1080);ctx.fillStyle='white';ctx.font='50px sans-serif';ctx.fillText('Wallpaper HD fixture — bukan frame aplikasi',90,400);
  const data=c.toDataURL('image/jpeg',.9).split(',')[1],total=Math.ceil(data.length/16384);
  const deliver=()=>{for(let index=0;index<total;index++)queueMicrotask(()=>this.wallpaperTransfer.receive({type:'wallpaper',id,index,total,data:data.slice(index*16384,(index+1)*16384)}));};
  if(window.__holdWallpaper)window.__deliverWallpaper=deliver;else deliver();
 }
};
RtcSession.prototype.readStats=async function(){return null;};
RtcSession.prototype.stop=function(){};
`;
 },
 configureServer(s){s.middlewares.use('/control-fixture',(_q,r)=>{r.setHeader('content-type','text/html; charset=utf-8');r.end(`<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div id="root"></div><script type="module">import React from '/node_modules/.vite/deps/react.js';import client from'/node_modules/.vite/deps/react-dom_client.js';import{ConnectScreen}from'/src/App.tsx';import'/src/style.css';client.createRoot(document.getElementById('root')).render(React.createElement(ConnectScreen,{ensureToken:async()=>'fixture',accountName:''}));</script></body></html>`);});}
}]});
await server.listen();const base='http://127.0.0.1:'+server.httpServer.address().port;
const browser = await chromium.launch({headless:true,args:['--no-sandbox']});
const checks=[];
try {
 for(const viewport of [{width:390,height:844},{width:844,height:390}]){
  const context=await browser.newContext({viewport,isMobile:true,hasTouch:true});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base+'/control-fixture');
  await page.locator('.host-id').fill('123456789');await page.locator('.pw-field input').fill('fixture-password');await page.locator('.connect-cta').click();
  await page.waitForFunction(()=>JSON.parse(localStorage.getItem('xydesk.guest.history.v1')||'[]')[0]?.preview);
  assert.equal(await page.evaluate(()=>window.__inputs.filter(b=>b[0]===13).length),1);
  assert.equal(await page.locator('.history-consent').count(),0);
  await page.getByRole('button',{name:'Pengaturan sesi',exact:true}).click();
  await page.getByRole('button',{name:'60 FPS',exact:true}).click();
  assert.ok(await page.evaluate(()=>window.__inputs.some(b=>b[0]===15&&b[1]===60)));
  for(const label of ['Otomatis','Sedang','Tinggi','Sangat tinggi'])assert.ok(await page.getByRole('button',{name:label,exact:true}).count()>0);
  await page.screenshot({path:new URL('../../docs/qa/uxfinish-video-'+viewport.width+'.png',import.meta.url).pathname});
  assert.deepEqual(errors,[]);checks.push({viewport,automaticWallpaperOnce:true,fpsCommand:true,qualityPresets:true});await context.close();
 }
 const proof={pass:true,checks,scope:'Browser/protocol fixture only; not Windows performance proof'};
 writeFileSync(new URL('../../docs/qa/uxfinish-video-2026-09-19.json',import.meta.url),JSON.stringify(proof,null,2));console.log(JSON.stringify(proof));
}finally{await browser.close();await server.close();}
