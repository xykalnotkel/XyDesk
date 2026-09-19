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
 },configureServer(s){s.middlewares.use('/remember-fixture',(_q,r)=>{r.setHeader('content-type','text/html');r.end(`<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module">import React from '/node_modules/.vite/deps/react.js';import client from '/node_modules/.vite/deps/react-dom_client.js';import {ConnectScreen} from '/src/App.tsx';import '/src/style.css';client.createRoot(document.getElementById('root')).render(React.createElement(ConnectScreen,{initialHostId:'123456789',returnPath:'/remember-fixture',ensureToken:async()=>'fixture',accountName:''}));</script></body></html>`);});}
}]});await server.listen();const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{
 const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:4178/remember-fixture');await page.locator('.pw-field input').fill('private-test-password');await page.locator('.connect-cta').click();
 await page.waitForFunction(()=>localStorage.getItem('xydesk.guest.hostAccess.v1.123456789'));
 assert.equal(await page.evaluate(()=>JSON.stringify({...localStorage}).includes('private-test-password')),false);
 // Transport loss must use saved authorization, not the captured original password.
 await page.evaluate(()=>window.__session.onPhase('error'));
 await page.waitForFunction(()=>window.__calls.length===2);
 let calls=await page.evaluate(()=>window.__calls);assert.equal(calls[1].pin,'');assert.equal(calls[1].access.resumeToken,'a'.repeat(64));
 await page.reload();await page.waitForSelector('.connect-cta');assert.equal(await page.locator('.pw-field input').count(),0);assert.equal(await page.locator('.connect-cta').isEnabled(),true);
 await page.screenshot({path:new URL('../../docs/qa/uxfinish-access-2026-09-19.png',import.meta.url).pathname,fullPage:true});
 await page.locator('.connect-cta').click();await page.waitForFunction(()=>window.__calls?.length===1&&window.__ready===true);
 calls=await page.evaluate(()=>window.__calls);assert.equal(calls[0].access.resumeToken,'a'.repeat(64));assert.equal(calls[0].pin,'');
 await page.evaluate(()=>{window.__session.onRememberedRejected();window.__session.reconnectAllowed=false;window.__session.onPhase('ended');});await page.waitForTimeout(2400);
 assert.equal(await page.evaluate(()=>window.__calls.length),1);assert.equal(await page.evaluate(()=>localStorage.getItem('xydesk.guest.hostAccess.v1.123456789')),null);
 await page.evaluate(()=>localStorage.clear());await page.reload();await page.waitForSelector('.connect-cta');assert.equal(await page.locator('.connect-cta').isDisabled(),true);
 assert.ok((await page.locator('.microcopy').innerText()).includes('tanpa batas durasi'));assert.deepEqual(errors,[]);
 const proof={pass:true,checks:['password not persisted','error reconnect uses saved grant, no captured password','reload remembers access without password','owner rejection clears grant and blocks auto reconnect','clearing site data requires new pairing','guest no countdown copy'],scope:'React/browser fixture; no physical Windows cursor or RDP test'};writeFileSync(new URL('../../docs/qa/uxfinish-access-2026-09-19.json',import.meta.url),JSON.stringify(proof,null,2));console.log(JSON.stringify(proof));
}finally{await browser.close();await server.close();}
