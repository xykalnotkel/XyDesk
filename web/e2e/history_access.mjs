// Real React connection UI with a protocol fixture; not a Windows capture test.
import {createServer} from 'vite';import {chromium} from 'playwright';import assert from 'node:assert/strict';import {writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url).pathname;
const server=await createServer({root,configFile:false,oxc:{jsx:{runtime:'automatic'}},server:{host:'127.0.0.1',port:4178},plugins:[{
 name:'remembered-access-fixture',enforce:'pre',transform(source,id){
 if(id.endsWith('/src/App.tsx'))return source+'\nexport {ConnectScreen};';
 if(id.endsWith('/src/rtc.ts'))return source+`
RtcSession.prototype.start=async function(jwt,host,pin,access){
 window.__calls=window.__calls||[];window.__calls.push({host,pin,access});window.__session=this;
 this.onPhase('pairing');await new Promise(r=>setTimeout(r,20));
 if(access?.remember)this.onRememberedAccess('a'.repeat(64));
 this.onPhase('connected');window.__ready=true;
 const c=document.createElement('canvas');c.width=1280;c.height=720;c.getContext('2d').fillRect(0,0,1280,720);this.onTrack(c.captureStream(2));
};RtcSession.prototype.stop=function(){};RtcSession.prototype.sendInput=function(){};RtcSession.prototype.readStats=async function(){return null;};`;
 },configureServer(s){s.middlewares.use('/history-fixture',(_q,r)=>{r.setHeader('content-type','text/html');r.end(`<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module">import React from '/node_modules/.vite/deps/react.js';import client from '/node_modules/.vite/deps/react-dom_client.js';import {ConnectScreen} from '/src/App.tsx';import {SessionHistoryPage} from '/src/session_history.tsx';import '/src/style.css';const connect=(id,history)=>React.createElement(ConnectScreen,{initialHostId:id,returnPath:history?'/history':'/connect',ensureToken:async()=>'fixture',accountName:''});client.createRoot(document.getElementById('root')).render(location.search.includes('history')?React.createElement(SessionHistoryPage,{renderReconnect:item=>connect(item.deviceId,true)}):connect('123456789',false));</script></body></html>`);});}
}]});await server.listen();const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{
 const results=[];
 for(const member of [false,true]){
  const context=await browser.newContext({viewport:{width:844,height:390},isMobile:true,hasTouch:true});
  const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const item={id:'fixture-history',deviceId:'123456789',name:'Console PC',startedAt:Date.now()-5000,endedAt:Date.now(),state:'ended',specs:{},preview:null};
  await page.route('**/auth/session-history',route=>route.fulfill({json:{items:[item]}}));
  await page.goto('http://127.0.0.1:4178/history-fixture');
  if(member){await page.evaluate(()=>localStorage.setItem('xydesk.web.jwt','e30.'+btoa(JSON.stringify({sub:'history-owner',exp:Date.now()/1000+900}))+'.fixture'));await page.reload();}
  await page.locator('.pw-field input').fill('private-test-password');await page.locator('.connect-cta').click();
  await page.waitForFunction(()=>window.__ready===true);
  assert.equal(await page.evaluate(()=>JSON.stringify({...localStorage}).includes('private-test-password')),false);
  await page.evaluate(row=>localStorage.setItem('xydesk.guest.history.v1',JSON.stringify([row])),item);
  await page.goto('http://127.0.0.1:4178/history-fixture?history');
  await page.getByRole('button',{name:'Hubungkan lagi Console PC',exact:true}).click();
  await page.waitForFunction(()=>window.__ready===true);
  const calls=await page.evaluate(()=>window.__calls);
  assert.equal(calls.length,1);assert.equal(calls[0].pin,'');assert.equal(calls[0].access.resumeToken,'a'.repeat(64));
  assert.equal(await page.locator('.pw-field').count(),0);assert.equal(await page.locator('.history-consent').count(),0);
  assert.equal(await page.locator('.mouse-hud').count(),0);
  await page.getByRole('button',{name:'Mapping Klik kanan',exact:true}).waitFor();
  assert.equal(await page.locator('.mapping-button').first().evaluate(el=>getComputedStyle(el).backgroundColor),'rgba(0, 0, 0, 0)');
  await page.getByRole('button',{name:'Keyboard',exact:true}).click();await page.locator('.vkb').waitFor();
  await page.screenshot({path:new URL('../../docs/qa/uxfinish-keyboard-'+(member?'member':'guest')+'.png',import.meta.url).pathname});
  await page.getByRole('button',{name:'Tutup keyboard',exact:true}).click();
  await page.getByRole('button',{name:'Atur tombol',exact:true}).click();
  await page.getByRole('button',{name:'Mapping Klik kanan',exact:true}).click();
  await page.getByRole('button',{name:'Properti tombol',exact:true}).click();
  assert.equal(await page.locator('.mapping-editor select').count(),0);
  assert.equal(await page.locator('.mapping-editor input[type=range]').count(),2);
  await page.screenshot({path:new URL('../../docs/qa/uxfinish-controls-'+(member?'member':'guest')+'.png',import.meta.url).pathname});
  assert.deepEqual(errors,[]);results.push({member,historyCardAutoResume:true,noPassword:true,transparentNamedControls:true,radiusSize:true,keyboard:true});await context.close();
 }
 const proof={pass:true,results,scope:'Real React history-card/dialog/browser storage and controls with transport fixture; not Windows field validation'};
 writeFileSync(new URL('../../docs/qa/uxfinish-history-2026-09-19.json',import.meta.url),JSON.stringify(proof,null,2));console.log(JSON.stringify(proof));
}finally{await browser.close();await server.close();}
