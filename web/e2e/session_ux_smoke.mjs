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
 this.onMeta?.(this.meta={cursorEmbedded:true,video:{applied:[1280,720],contentRect:[0,64,1280,592],level:51,requested:1,fpsLimit:30},displays:[],wanted:0,audio:{available:true,pipeline:'fixture'},hardware:{hostname:'PC uji sintetis',cpu:'Fixture CPU',ram:'Fixture RAM'}});
 this.onMeta?.(this.meta={cursorEmbedded:true,video:{applied:[1280,720],contentRect:[0,64,1280,592],level:51,requested:1,fpsLimit:30},displays:[],wanted:0,audio:{available:true,pipeline:'fixture'},hardware:{hostname:'PC uji sintetis',cpu:'Fixture CPU',ram:'Fixture RAM'}});

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
 configureServer(s){s.middlewares.use('/control-fixture',(_q,r)=>{r.setHeader('content-type','text/html');r.end(`<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div id="root"></div><script type="module">import React from '/node_modules/.vite/deps/react.js';import client from'/node_modules/.vite/deps/react-dom_client.js';import{ConnectScreen}from'/src/App.tsx';import'/src/style.css';client.createRoot(document.getElementById('root')).render(React.createElement(ConnectScreen,{ensureToken:async()=>'fixture',accountName:''}));</script></body></html>`);});}
}]});
await server.listen();
const browser = await chromium.launch({headless:true,args:['--no-sandbox']});
const checks=[];
try{
 for(const viewport of [{width:390,height:844},{width:844,height:390}]){
  const context=await browser.newContext({viewport,isMobile:true,hasTouch:true});const page=await context.newPage();page.setDefaultTimeout(10000);console.log('viewport',viewport);
  const errors=[];page.on('pageerror',e=>{errors.push(e.message);console.error(e.message);});page.on('console',m=>{if(m.type()==='error')console.error(m.text());});
  await page.addInitScript(()=>{
 localStorage.setItem('xydesk.session.prefs',JSON.stringify({quality:'high',bitrateMbps:15,volume:.4}));
 const original=HTMLMediaElement.prototype.play;window.__audioCalls=0;
 HTMLMediaElement.prototype.play=function(){if(this.tagName==='AUDIO'&&++window.__audioCalls===1)return Promise.reject(new DOMException('fixture autoplay block','NotAllowedError'));return original.call(this);};
 });
 await page.goto('http://127.0.0.1:4177/control-fixture');
  await page.locator('input').nth(0).fill('123456789');await page.locator('input').nth(1).fill('fixture');
  await page.getByRole('button',{name:'Konek sekarang',exact:true}).click();
  await page.locator('.session-connecting').waitFor({state:'visible'});
  await page.getByRole('button',{name:'Kembali / batalkan',exact:true}).click();
  await page.waitForFunction(()=>window.__fixtureStartDone===1);
  assert.equal(await page.locator('.connect-form').isVisible(),true);
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('xydesk.guest.history.v1'))[0].state),'cancelled');
  await page.evaluate(()=>localStorage.removeItem('xydesk.guest.history.v1'));
  await page.locator('.history-consent input').check();
  await page.getByRole('button',{name:'Konek sekarang',exact:true}).click();
  await page.locator('.remote-session .session-connecting').waitFor({state:'visible'});
  assert.equal(await page.locator('.connect-form').count(),0);
  await page.waitForFunction(()=>document.querySelector('video')?.videoWidth===1280);
  console.log('video loaded');
  await page.waitForFunction(()=>JSON.parse(localStorage.getItem('xydesk.guest.history.v1')||'[]')[0]?.preview);
  const previewSize=await page.evaluate(async()=>{const image=new Image();image.src=JSON.parse(localStorage.getItem('xydesk.guest.history.v1'))[0].preview;await image.decode();return [image.naturalWidth,image.naturalHeight];});assert.deepEqual(previewSize,[1920,1080]);
  assert.equal(await page.evaluate(()=>window.__inputs.filter(b=>b[0]===13).length),1);
  await page.getByRole('button',{name:'Keyboard',exact:true}).click();
  if(viewport.width===844)await page.screenshot({path:new URL('../../docs/qa/letterbox-keyboard-2026-09-18.png',import.meta.url).pathname});
  await page.locator('.vkb').getByRole('button',{name:'Ctrl',exact:true}).click();
  await page.getByRole('button',{name:'Tutup keyboard',exact:true}).click();
  assert.equal(await page.locator('.vkb').count(),0);
  assert.deepEqual(await page.evaluate(()=>window.__inputs.filter(b=>b[0]===5).slice(-2).map(b=>[b[1],b[3]])),[[162,1],[162,0]]);

  assert.match(new URL(page.url()).hash,/^#session\/[0-9a-f]{64}$/);
  let initial=await page.evaluate(()=>window.__inputs);
  assert.equal(initial.filter(b=>b[0]===10).length,1);assert.equal(initial.filter(b=>b[0]===11).length,1);
  assert.equal(initial.find(b=>b[0]===11)[1],15);
  await page.getByRole('button',{name:'Aktifkan suara',exact:true}).click();
  await page.waitForFunction(()=>!document.querySelector('audio').paused);
  assert.equal(await page.locator('audio').evaluate(e=>e.volume),.4);
  await page.getByRole('button',{name:'Suara PC',exact:true}).click();
  assert.equal(await page.locator('audio').evaluate(e=>e.muted),true);
  await page.getByRole('button',{name:'Suara PC',exact:true}).click();
  assert.equal(await page.locator('audio').evaluate(e=>e.muted),false);
assert.equal(await page.locator('.remote-control-cursor').isVisible(),false);
  assert.equal(await page.getByRole('button',{name:'Mode trackpad',exact:true}).getAttribute('aria-pressed'),'true');
  const cdp=await context.newCDPSession(page);
  const touch=async(type,points)=>{return cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points.map(([id,x,y])=>({id,x,y}))});};
  const x=viewport.width*.30,y=viewport.height*.5;
  await page.evaluate(()=>window.__inputs=[]);
  await touch('touchStart',[[1,x,y]]);await touch('touchMove',[[1,x+35,y+8]]);await touch('touchEnd',[]);
  let inputs=await page.evaluate(()=>window.__inputs);
  assert.ok(inputs.some(b=>b[0]===2));assert.equal(inputs.filter(b=>b[0]===3).length,0);
  assert.equal(await page.locator('.remote-control-cursor').isVisible(),false);
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
  const expectedX=await page.evaluate(x=>{const v=document.querySelector('video'),b=v.getBoundingClientRect(),scale=Math.min(b.width/v.videoWidth,b.height/v.videoHeight),w=v.videoWidth*scale;return (x-b.left-(b.width-w)/2)/w;},x);
  assert.ok(Math.abs((inputs[0][1]+inputs[0][2]*256)/65535-expectedX)<.002);
  await page.getByRole('button',{name:'Keluar layar penuh',exact:true}).click();
  await page.getByRole('button',{name:'Layar penuh',exact:true}).click();
  await page.waitForFunction(()=>document.fullscreenElement?.className==='video-surface');
  assert.equal(await page.locator('.remote-control-cursor').isVisible(),false);
  await page.getByRole('button',{name:'Keluar layar penuh',exact:true}).click();
  await page.getByRole('button',{name:'Temukan panah',exact:true}).click();
  let center=await page.evaluate(()=>window.__inputs.filter(b=>b[0]===2).at(-1));
  assert.ok(Math.abs((center[1]+center[2]*256)/65535-.5)<.001);
  await page.getByRole('button',{name:'Panel gaming',exact:true}).click();
  await page.getByRole('button',{name:'Atur tombol',exact:true}).click();
  const mapped=page.getByRole('button',{name:'Mapping Spasi',exact:true});const before=await mapped.boundingBox();
  await page.evaluate(()=>window.__inputs=[]);
  await page.mouse.move(before.x+before.width/2,before.y+before.height/2);await page.mouse.down();await page.mouse.move(before.x-60,before.y+20);await page.mouse.up();
  assert.equal((await page.evaluate(()=>window.__inputs)).filter(b=>b[0]===5).length,0);
  await page.getByRole('button',{name:'Properti tombol',exact:true}).click();
  await page.getByRole('slider').fill('84');
  await page.getByRole('button',{name:'Simpan layout',exact:true}).click();
  assert.equal(Math.round((await mapped.boundingBox()).width),84);
  assert.ok(await page.evaluate(()=>localStorage.getItem('xydesk.mapping.v1')));
  await page.getByRole('button',{name:'Atur tombol',exact:true}).click();
  await mapped.click();
  await page.getByRole('button',{name:'Properti tombol',exact:true}).click();
  await page.locator('.mapping-editor select').first().selectOption('chord');
  await page.locator('.mapping-editor select[multiple]').selectOption(['17','67']);
  await page.getByLabel('Nama',{exact:true}).fill('Ctrl+C');
  await page.getByRole('button',{name:'Simpan layout',exact:true}).click();
  await page.evaluate(()=>window.__inputs=[]);
  await page.keyboard.down('ControlLeft');
  await page.getByRole('button',{name:'Mapping Ctrl+C',exact:true}).click();
  await page.keyboard.up('ControlLeft');
  assert.deepEqual(await page.evaluate(()=>window.__inputs.filter(b=>b[0]===5).map(b=>[b[1],b[3]])),[[162,1],[67,1],[67,0],[162,0]]);

  await page.getByRole('button',{name:'Panel gaming',exact:true}).click();
  assert.deepEqual(errors,[]);
  const inputCount=await page.evaluate(()=>window.__inputs.length);
  await page.evaluate(()=>window.__fixtureSession.onCursor({x:.2,y:.4,visible:true}));await page.waitForTimeout(60);

  await page.evaluate(()=>window.__fixtureSession.onCursor({x:.8,y:.4,visible:true}));await page.waitForTimeout(60);
  assert.equal(await page.locator('.remote-control-cursor').isVisible(),false);
  assert.equal(await page.evaluate(()=>window.__inputs.length),inputCount);
  checks.push({wallpaperHD:true,previewIndependentOfVideo:true,cursorFeedbackNoInjection:true,connectFullscreen:true,viewport,defaultTrackpad:true,localArrowHidden:true,swipe:true,tap:true,cancelNoClick:true,holdAndDrag:true,twoFingerScroll:true,directPositionBeforeClick:true,localArrowHiddenInFullscreen:true,centerButton:true,audioPlayRetry:true,audioMute:true,savedPrefsSentOnce:true,randomUrl:true,loadingInsideSession:true,cancelDoesNotResurrect:true,guestHistoryPreviewAndPage:true,automaticPreviewOnce:true,keyboardDismissReleasesModifier:true,mappingMoveResizeSave:true,chordWithPhysicalModifier:true,oneCardPerDevice:true,pageErrors:errors});
  if(viewport.width===844)await page.screenshot({path:new URL('../../docs/qa/letterbox-ui-2026-09-18.png',import.meta.url).pathname});
  await page.getByRole('button',{name:'Putuskan',exact:true}).click();
  const rows=await page.evaluate(()=>JSON.parse(localStorage.getItem('xydesk.guest.history.v1')));
  assert.equal(rows.length,1);assert.equal(rows[0].state,'ended');assert.equal(rows[0].name,'PC uji sintetis');assert.ok(rows[0].preview?.startsWith('data:image/jpeg;base64,'));
  await page.evaluate(()=>{const key='xydesk.guest.history.v1',rows=JSON.parse(localStorage.getItem(key));rows.push({...rows[0],id:crypto.randomUUID(),endedAt:rows[0].endedAt-1});localStorage.setItem(key,JSON.stringify(rows));});
  await page.getByRole('link',{name:'Buka halaman riwayat',exact:true}).click();
  await page.getByRole('heading',{name:'Riwayat koneksi',exact:true}).waitFor();
  assert.equal(await page.getByRole('heading',{name:'PC uji sintetis',exact:true}).count(),1);
  if(viewport.width===844)await page.screenshot({fullPage:true,path:new URL('../../docs/qa/letterbox-history-2026-09-18.png',import.meta.url).pathname});
  await context.close();
 }
 // Opt-out before connecting; then revoke while a transfer is in flight.
 for(const scenario of ['opt-out','revoke-pending']){
  const context=await browser.newContext({viewport:{width:390,height:844}}),page=await context.newPage();
  await page.goto('http://127.0.0.1:4177/control-fixture');
  await page.locator('input').nth(0).fill('123456789');await page.locator('input').nth(1).fill('fixture');
  if(scenario==='opt-out')await page.locator('.history-consent input').uncheck();else await page.evaluate(()=>window.__holdWallpaper=true);
  await page.getByRole('button',{name:'Konek sekarang',exact:true}).click();
  await page.waitForFunction(()=>window.__fixtureStartDone===1);
  if(scenario==='opt-out'){await page.waitForTimeout(200);assert.equal(await page.evaluate(()=>window.__inputs.filter(b=>b[0]===13).length),0);}
  else{
    await page.waitForFunction(()=>window.__deliverWallpaper);
    await page.getByRole('button',{name:'Pengaturan sesi',exact:true}).click();await page.getByRole('tab',{name:'Sesi',exact:true}).click();
    await page.getByRole('switch',{name:'Preview wallpaper otomatis',exact:true}).click();
    await page.evaluate(()=>window.__deliverWallpaper());await page.waitForTimeout(100);
    assert.equal(await page.evaluate(()=>window.__fixtureSession.wallpaperTransfer.pending),null);
    await page.locator('.spanel-close').click();
  }
  assert.equal(await page.evaluate(()=>localStorage.getItem('xydesk.guest.history.v1')),null);
  await page.getByRole('button',{name:'Putuskan',exact:true}).click();
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('xydesk.guest.history.v1'))[0].preview),null);
  checks.push({scenario,result:'PASS'});await context.close();
 }
 writeFileSync(new URL('../../docs/qa/letterbox-ui-2026-09-18.json',import.meta.url),JSON.stringify({result:'PASS',boundary:'Real React handlers, Chromium CDP touch events, local canvas stream; stubbed RtcSession transport, not Windows/Android injection',checks},null,2)+'\n');
 console.log(JSON.stringify(checks));
}finally{await browser.close();await server.close();}
