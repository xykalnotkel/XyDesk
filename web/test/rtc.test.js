import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';
import { transformWithOxc } from 'vite';

// Transformasi TypeScript memakai compiler yang sama dengan build web.
// Hanya binding modul yang dialihkan ke fixture; logika RtcSession tetap asli.
const input = readFileSync(new URL('../src/rtc.ts', import.meta.url), 'utf8')
  .replace(/^import \{([^}]+)\} from '\.\/api';/m, 'const {$1} = api;')
  .replace(/^import .*$/gm, '')
  .replace(/^export /gm, '');
const dependencies=['preview_jpeg.ts','wallpaper_transfer.ts','video_negotiation.ts'].map(name=>readFileSync(new URL('../src/'+name,import.meta.url),'utf8').replace(/^import .*$/gm,'').replace(/^export /gm,'')).join('\n');
const { code } = await transformWithOxc(dependencies+'\n'+input + '\nexports.RtcSession = RtcSession;', 'rtc.ts');
const source = code;

function setup(overrides = {}) {
  const sockets = [];
  class Socket {
    static OPEN = 1;
    readyState = 1;
    sent = [];
    closed = 0;
    constructor() { sockets.push(this); }
    send(data) { this.sent.push(JSON.parse(data)); }
    close() { this.closed++; this.readyState = 3; }
  }
  const exports = {};
  vm.runInNewContext(source, {
    exports, api: { signalToken: async () => 'local-token', WS_URL: 'ws://local/ws', turnIce: async () => [], ...overrides },
    WebSocket: Socket, crypto: webcrypto, setTimeout, clearTimeout,
    TextEncoder, TextDecoder, Uint8Array, ArrayBuffer, performance, navigator: overrides.navigator,
  });
  return { session: new exports.RtcSession(), sockets };
}

for (const phase of ['error', 'ended', 'rejected', 'host-busy', 'peer-offline']) {
  test(`fase ${phase} menutup transport satu kali dan mempertahankan pesan`, async () => {
    const { session, sockets } = setup();
    await session.start('jwt', '100200300', 'fixture');
    let peers = 0, inputs = 0;
    session.pc = { close: () => peers++ };
    session.input = { close: () => inputs++ };
    session.setPhase(phase, 'pesan uji');
    assert.equal(session.phase, phase);
    assert.equal(peers, 1);
    assert.equal(inputs, 1);
    assert.equal(sockets[0].closed, 1);
    assert.equal(session.lastError, 'pesan uji');
    assert.equal(sockets[0].sent.at(-1).type, 'bye');
    session.stop();
    assert.equal(peers, 1);
  });
}

test('ICE menunggu setRemoteDescription dan pesan peer lain diabaikan', async () => {
  const { session, sockets } = setup();
  await session.start('jwt', '100200300', 'fixture');
  const order = [];
  let finish;
  session.pc = {
    setRemoteDescription: async () => {
      order.push('answer-start');
      await new Promise(resolve => { finish = resolve; });
      order.push('answer-done');
    },
    addIceCandidate: async () => order.push('ice'),
    close() {},
  };
  const send = message => sockets[0].onmessage({ data: JSON.stringify(message) });
  try {
    send({ type: 'bye', from: 'host-lain' });
    send({ type: 'answer', from: '100200300', sdp: { sdp: 'test' } });
    send({ type: 'ice', from: '100200300', candidate: { candidate: 'test' } });
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(order, ['answer-start']);
    finish();
    await session.messages;
    assert.deepEqual(order, ['answer-start', 'answer-done', 'ice']);
    assert.equal(session.stopped, false);
  } finally { session.stop(); }
});

test('jawaban rusak menjadi error terkontrol, bukan rejection tanpa handler', async () => {
  const { session, sockets } = setup();
  await session.start('jwt', '100200300', 'fixture');
  let closed = false;
  session.pc = { setRemoteDescription: async () => { throw new Error('SDP invalid'); }, close: () => { closed = true; } };
  sockets[0].onmessage({ data: JSON.stringify({ type: 'answer', from: '100200300', sdp: { sdp: 'bad' } }) });
  await session.messages;
  assert.equal(session.phase, 'error');
  assert.equal(closed, true);
});

test('stop ketika menunggu TURN tidak membuat peer connection terlambat', async () => {
  let finish;
  const { session } = setup({ turnIce: () => new Promise(resolve => { finish = resolve; }) });
  const pending = session.negotiate();
  session.stop();
  finish([]);
  await pending;
  assert.equal(session.pc, undefined);
});

test('ID client tidak bertabrakan pada waktu yang sama', async () => {
  const a = setup().session, b = setup().session;
  try {
    await Promise.all([a.start('jwt', '100200300', 'fixture'), b.start('jwt', '100200300', 'fixture')]);
    assert.notEqual(a.deviceId, b.deviceId);
    assert.match(a.deviceId, /^web-[0-9a-f-]{36}$/);
  } finally { a.stop(); b.stop(); }
});

test('signaling putus saat connected menutup media dan menampilkan sebabnya', async () => {
  const { session, sockets } = setup();
  await session.start('jwt', '100200300', 'fixture');
  let closed = false;
  session.pc = { close: () => { closed = true; } };
  session.setPhase('connected');
  sockets[0].onclose({ code: 1000 });
  assert.equal(closed, true);
  assert.equal(session.phase, 'error');
  assert.match(session.lastError, /signaling terputus/);
});

test('label codec dibaca dari codecId, bukan field inbound RTP yang tidak ada', async () => {
  const { session } = setup();
  session.pc = {
    connectionState: 'connected', close() {},
    getStats: async () => new Map([
      ['video', { type: 'inbound-rtp', kind: 'video', codecId: 'h264', frameWidth: 320, frameHeight: 180, framesDecoded: 5 }],
      ['h264', { type: 'codec', mimeType: 'video/H264', sdpFmtpLine: 'profile-level-id=42e01f' }],
    ]),
  };
  try {
    const stats = await session.readStats();
    assert.equal(stats.codec, 'H264 (42e01f)');
  } finally { session.stop(); }
});


test('stop ketika menunggu token tidak membuka signaling terlambat', async () => {
  let finish;
  const { session, sockets } = setup({ signalToken: () => new Promise(resolve => { finish = resolve; }) });
  const pending = session.start('jwt', '100200300', 'fixture');
  session.stop();
  finish('local-token');
  await pending;
  assert.equal(sockets.length, 0);
  assert.equal(session.phase, 'ended');
});


test('statistik memakai video utama bukan RTX dan mempertahankan hitungan kecil', async () => {
  const { session } = setup();
  const report = new Map([
    ['h264', { id: 'h264', type: 'codec', mimeType: 'video/H264', sdpFmtpLine: 'profile-level-id=42e01f' }],
    ['rtx', { id: 'rtx', type: 'codec', mimeType: 'video/rtx' }],
    ['video', { id: 'video', type: 'inbound-rtp', kind: 'video', codecId: 'h264', bytesReceived: 17, packetsReceived: 2, packetsLost: 1, framesDecoded: 0, pliCount: 3, nackCount: 4 }],
    ['repair', { id: 'repair', type: 'inbound-rtp', kind: 'video', codecId: 'rtx', bytesReceived: 900 }],
  ]);
  session.pc = { connectionState: 'connected', getStats: async () => report };
  const s = await session.readStats();
  assert.equal(s.codec, 'H264 (42e01f)');
  assert.equal(s.bytesReceived, 17);
  assert.equal(s.packetsReceived, 2);
  assert.equal(s.packetsLost, 1);
  assert.equal(s.framesDecoded, 0);
  assert.equal(s.pliCount, 3);
  assert.match(s.videoState, /belum ada frame terdecode/);
});

test('transport Connected tanpa laporan video tidak menyatakan decode berhasil', async () => {
  const { session } = setup();
  session.pc = { connectionState: 'connected', getStats: async () => new Map([
    ['pair', { id: 'pair', type: 'candidate-pair', nominated: true, state: 'succeeded', currentRoundTripTime: 0.23 }],
  ]) };
  const s = await session.readStats();
  assert.equal(s.rttMs, 230);
  assert.equal(s.bytesReceived, undefined);
  assert.match(s.videoState, /Belum ada laporan RTP/);
});

test('framesDecoded yang hilang tidak dipalsukan sebagai nol', async () => {
 const {session}=setup();session.pc={connectionState:'connected',getStats:async()=>new Map([
 ['video',{id:'video',type:'inbound-rtp',kind:'video',bytesReceived:1425749,framesReceived:720,keyFramesDecoded:6}],
 ])};const s=await session.readStats();assert.equal(s.framesDecoded,undefined);assert.equal(s.keyFramesDecoded,6);assert.match(s.videoState,/tidak tersedia/);
});
test('keyframe melebihi total decode ditandai inkonsisten', async () => {
 const {session}=setup();session.pc={connectionState:'connected',getStats:async()=>new Map([
 ['video',{id:'video',type:'inbound-rtp',kind:'video',bytesReceived:1425749,framesDecoded:0,keyFramesDecoded:6}],
 ])};assert.match((await session.readStats()).videoState,/tidak konsisten/);
});

test('mute receiver lokal tidak mengubah SDP atau mic sender', async()=>{
 const {session}=setup();let stopped=0;const receiver={enabled:true};const sender={enabled:true,stop:()=>stopped++};
 session.audioTransceiver={direction:'sendrecv',receiver:{track:receiver},sender:{track:sender}};
 await session.setAudioEnabled(false);assert.equal(receiver.enabled,false);assert.equal(sender.enabled,true);assert.equal(stopped,0);assert.equal(session.audioTransceiver.direction,'sendrecv');
 await session.setAudioEnabled(true);assert.equal(receiver.enabled,true);
});
test('statistik audio terpisah dari video dan energi tak tersedia tidak dikarang',async()=>{
 const {session}=setup();const report=new Map([
 ['a',{id:'a',type:'inbound-rtp',kind:'audio',bytesReceived:125,totalAudioEnergy:.5}],
 ['b',{id:'b',type:'inbound-rtp',mediaType:'audio',bytesReceived:25}],
 ['v',{id:'v',type:'inbound-rtp',kind:'video',bytesReceived:900}],
 ]);session.pc={connectionState:'connected',getStats:async()=>report};let s=await session.readStats();assert.equal(s.audioBytesReceived,150);assert.equal(s.audioEnergy,.5);assert.equal(s.bytesReceived,900);
 report.delete('a');s=await session.readStats();assert.equal(s.audioEnergy,undefined);
});

test('geometry-less capture blocks pointer downs but never blocks release',()=>{const {session}=setup();const sent=[];session.input={readyState:'open',send:b=>sent.push([...new Uint8Array(b)])};session.meta={inputGeometry:null};for(const b of [[2,0,0,0,0],[3,0,1],[3,0,0],[5,17,0,0]])session.sendInput(new Uint8Array(b));assert.deepEqual(sent,[[3,0,0],[5,17,0,0]]);session.meta={inputGeometry:{left:0,top:0,width:1920,height:1080}};session.sendInput(new Uint8Array([3,0,1]));assert.equal(sent.length,3);});

test('jitter seconds and interval buffer/decode/loss are separate from RTT',async()=>{
 const {session}=setup();const x={id:'v',type:'inbound-rtp',kind:'video',codecId:'h264',bytesReceived:1000,packetsReceived:100,packetsLost:1,framesDecoded:10,jitter:.012,jitterBufferDelay:.2,jitterBufferEmittedCount:10,totalDecodeTime:.03};
 session.pc={connectionState:'connected',getStats:async()=>new Map([['v',x],['h264',{mimeType:'video/H264'}],['pair',{type:'candidate-pair',nominated:true,state:'succeeded',currentRoundTripTime:.08}]])};
 const first=await session.readStats();assert.equal(first.jitterMs,12);assert.equal(first.rttMs,80);assert.equal(first.decodeMs,undefined);assert.equal(first.jitterBufferMs,undefined);
 Object.assign(x,{packetsReceived:198,packetsLost:3,framesDecoded:20,jitterBufferDelay:.5,jitterBufferEmittedCount:20,totalDecodeTime:.08});
 const next=await session.readStats();assert.ok(Math.abs(next.jitterBufferMs-30)<1e-8);assert.ok(Math.abs(next.decodeMs-5)<1e-8);assert.equal(next.recentLossPct,2);
 const idle=await session.readStats();assert.equal(idle.decodeMs,undefined);assert.equal(idle.recentLossPct,undefined);
 x.id='new';x.framesDecoded=1;x.jitterBufferEmittedCount=1;const reset=await session.readStats();assert.equal(reset.decodeMs,undefined);assert.equal(reset.jitterBufferMs,undefined);
});

test('congested absolute movement is bounded/latest-only and flushed before click; key/release stays immediate',()=>{
 const {session}=setup(),sent=[];session.input={readyState:'open',bufferedAmount:2048,send:b=>sent.push([...new Uint8Array(b)])};
 for(let n=0;n<100;n++)session.sendInput(new Uint8Array([2,n,0]));
 assert.equal(sent.length,0);assert.equal(session.coalescedMoves,99);assert.deepEqual([...session.pendingAbsoluteMove],[2,99,0]);
 session.sendInput(new Uint8Array([5,65,0,1]));assert.deepEqual(sent,[[5,65,0,1]]);
 session.sendInput(new Uint8Array([3,0,1]));assert.deepEqual(sent.slice(-2),[[2,99,0],[3,0,1]]);
 session.sendInput(new Uint8Array([3,0,0]));assert.deepEqual(sent.at(-1),[3,0,0]);
 session.sendInput(new Uint8Array([2,42,0]));session.input.bufferedAmount=0;session.flushAbsoluteMove();assert.deepEqual(sent.at(-1),[2,42,0]);assert.equal(session.pendingAbsoluteMove,undefined);
 session.input.bufferedAmount=2048;session.sendInput(new Uint8Array([2,43,0]));session.meta={inputGeometry:null};session.input.bufferedAmount=0;session.flushAbsoluteMove();assert.equal(session.pendingAbsoluteMove,undefined);assert.deepEqual(sent.at(-1),[2,42,0]);
});

function microphoneFixture(getUserMedia) {
  const {session} = setup({navigator:{mediaDevices:{getUserMedia}}});
  const replacements=[];
  session.pc={close(){}};
  session.audioTransceiver={sender:{replaceTrack:async track=>{replacements.push(track);}}};
  return {session,replacements};
}
function microphoneStream() {
  const track={stopped:0,stop(){this.stopped++;}};
  return {track,getAudioTracks:()=>[track],getTracks:()=>[track]};
}

test('mic reuses negotiated sender on every enable/disable; no addTrack',async()=>{
  const streams=[];
  const {session,replacements}=microphoneFixture(async()=>{const s=microphoneStream();streams.push(s);return s;});
  assert.equal(await session.enableMic(),null);
  await session.disableMic();
  assert.equal(streams[0].track.stopped,1);
  assert.equal(await session.enableMic(),null);
  assert.deepEqual(replacements,[streams[0].track,null,streams[1].track]);
  await session.disableMic();
});

test('closing session while permission is pending stops the late track',async()=>{
  let resolve;
  const {session,replacements}=microphoneFixture(()=>new Promise(r=>resolve=r));
  const pending=session.enableMic();session.stop();
  const stream=microphoneStream();resolve(stream);
  assert.match(await pending,/dibatalkan/);
  assert.equal(stream.track.stopped,1);
  assert.equal(session.micEnabled,false);
  assert.ok(replacements.every(t=>t===null));
});

test('rapid double enable requests only one permission prompt',async()=>{
  let resolve,calls=0;
  const {session}=microphoneFixture(()=>{calls++;return new Promise(r=>resolve=r);});
  const a=session.enableMic(),b=session.enableMic();
  assert.equal(a,b);assert.equal(calls,1);resolve(microphoneStream());
  assert.equal(await a,null);await session.disableMic();
});

test('rejected replaceTrack cleans up microphone capture',async()=>{
  const stream=microphoneStream();const {session}=microphoneFixture(async()=>stream);
  session.audioTransceiver.sender.replaceTrack=async()=>{throw Error('closed');};
  assert.match(await session.enableMic(),/gagal/);
  assert.equal(stream.track.stopped,1);assert.equal(session.micEnabled,false);
  assert.equal(session.micStream,undefined);
});

test('missing virtual input is visible before requesting phone permission; old hosts compatible',async()=>{
  let calls=0;const {session}=microphoneFixture(async()=>{calls++;return microphoneStream();});
  session.meta={micInput:{available:false,route:'virtual-cable'}};
  assert.match(await session.enableMic(),/virtual audio cable/);assert.equal(calls,0);
  session.meta=null;assert.equal(await session.enableMic(),null);assert.equal(calls,1);
  await session.disableMic();
});

test('disable during replaceTrack is serialized after attachment',async()=>{
  const stream=microphoneStream();const {session}=microphoneFixture(async()=>stream);
  const changes=[];let resolve;
  session.audioTransceiver.sender.replaceTrack=track=>{changes.push(track);return track ? new Promise(r=>resolve=r) : Promise.resolve();};
  const enabled=session.enableMic();await new Promise(r=>setTimeout(r,0));
  const disabled=session.disableMic();resolve();
  assert.match(await enabled,/dibatalkan/);await disabled;
  assert.deepEqual(changes,[stream.track,null]);assert.equal(session.micEnabled,false);
  assert.ok(stream.track.stopped>=1);
});

test('remembered pairing sends grant, not pairing password; rejects foreign grant response',async()=>{
 const {session,sockets}=setup();session.negotiate=async()=>{};let remembered=null;session.onRememberedAccess=t=>{remembered=t;};
 await session.start('jwt','123456789','not-transmitted',{remember:true,resumeToken:'a'.repeat(64)});sockets[0].onopen();
 const pair=sockets[0].sent.find(x=>x.type==='pair');assert.equal(pair.pin,undefined);assert.equal(pair.resumeToken,'a'.repeat(64));
 await session.handle({type:'pair-response',from:'987654321',accepted:true,resumeToken:'b'.repeat(64)});assert.equal(remembered,null);
 await session.handle({type:'pair-response',from:'123456789',accepted:true,resumeToken:'b'.repeat(64)});assert.equal(remembered,'b'.repeat(64));session.stop();
});
test('revoked remembered access stops automatic reconnect and clears the saved grant',async()=>{
 const {session}=setup();let cleared=0;session.onRememberedRejected=()=>cleared++;
 await session.start('jwt','123456789','',{remember:true,resumeToken:'a'.repeat(64)});
 await session.handle({type:'pair-response',from:'123456789',accepted:false});assert.equal(cleared,1);assert.equal(session.reconnectAllowed,false);assert.equal(session.phase,'rejected');session.stop();
});
test('network bye permits reconnect but owner bye and 1008 do not',async()=>{
 for(const [reason,allowed] of [['peer-disconnected',true],['remembered-access-revoked',false],['admin-disconnect',false],['stop-session',false]]) {
  const {session}=setup();await session.start('jwt','123456789','password');await session.handle({type:'bye',from:'123456789',reason});assert.equal(session.reconnectAllowed,allowed);session.stop();
 }
 const {session,sockets}=setup();await session.start('jwt','123456789','password');sockets[0].onclose({code:1008});assert.equal(session.reconnectAllowed,false);session.stop();
});
test('FPS command requires advertised host capability and serializes selected target',()=>{const {session}=setup();const sent=[];session.sendInput=b=>sent.push(Array.from(b));session.setFps(60);assert.equal(sent.length,0);session.meta={video:{fpsControl:true}};session.setFps(60);session.setFps(30);assert.deepEqual(sent,[[15,60],[15,30]]);session.meta={video:{fpsLimit:30}};session.setFps(60);assert.equal(sent.length,2);});
