import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {transformWithOxc} from 'vite';
const {code}=await transformWithOxc(readFileSync(new URL('../src/video_playback.ts',import.meta.url),'utf8').replace(/^export /gm,'')+'\nexports.api={videoOnlyStream,playRemoteVideo};','video_playback.ts');
function api(){const exports={};vm.runInNewContext(code,{exports,MediaStream:class{constructor(tracks){this.tracks=tracks;}}});return exports.api;}
test('sink video hanya membawa track video, bukan audio yang tidak mengalir',()=>{
 const video={kind:'video'},audio={kind:'audio'};const stream={getVideoTracks:()=>[video],getTracks:()=>[video,audio]};
 const filtered=api().videoOnlyStream(stream);assert.equal(filtered.tracks.length,1);assert.equal(filtered.tracks[0],video);
});
test('play eksplisit mengaktifkan muted/inline dan tidak mengganti stream saat retry',async()=>{
 const stream={};let writes=0,plays=0;let src;
 const el={set srcObject(v){writes++;src=v;},get srcObject(){return src;},play:async()=>{plays++;}};
 const {playRemoteVideo}=api();await playRemoteVideo(el,stream);await playRemoteVideo(el,stream);
 assert.equal(el.muted,true);assert.equal(el.playsInline,true);assert.equal(writes,1);assert.equal(plays,2);
});
test('penolakan play diteruskan untuk tombol gesture, bukan ditelan',async()=>{
 const el={play:async()=>{throw new Error('NotAllowedError');}};
 await assert.rejects(api().playRemoteVideo(el,{}),/NotAllowedError/);
});
