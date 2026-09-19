import {chromium} from 'playwright';import assert from 'node:assert/strict';import {writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('https://app.xydesk.my.id/',{waitUntil:'networkidle'});
 const hero=page.locator('.hero-cartoon');await hero.waitFor();assert.ok((await hero.getAttribute('src')).endsWith('.webp'));
 assert.equal(await hero.evaluate(img=>img.naturalWidth),1672);
 assert.equal(await hero.evaluate(img=>img.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}))),false);
 await page.goto('https://app.xydesk.my.id/connect',{waitUntil:'networkidle'});await page.locator('.connect-cta').waitFor();
 assert.equal(await page.locator('.history-consent').count(),0);
 await page.goto('https://app.xydesk.my.id/history',{waitUntil:'networkidle'});await page.getByRole('heading',{name:'Riwayat koneksi',exact:true}).waitFor();
 assert.deepEqual(errors,[]);const proof={pass:true,heroWebp:true,nativeHeroWidth:1672,imageContextPrevented:true,noPreviewCheckbox:true,connectHistoryRoutes:true,noPairingAttempted:true,errors};
 writeFileSync(new URL('../../docs/qa/uxfinish-live-browser-2026-09-19.json',import.meta.url),JSON.stringify(proof,null,2));console.log(JSON.stringify(proof));
}finally{await browser.close();}
