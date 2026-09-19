export type VideoSample={recentLossPct?:number;jitterBufferMs?:number;rttMs?:number;decodeMs?:number;width?:number;height?:number;fps?:number};
// Slow recovery avoids oscillating encoder restarts. Unknown metrics never imply spare bandwidth.
export class AdaptiveVideo {
 target=8; private stable=0; private changed=0;
 reset(target=8){this.target=target;this.stable=0;this.changed=0;}
 update(s:VideoSample,ceiling:number,now:number):number|null {
  if(!Number.isFinite(s.recentLossPct)||!Number.isFinite(s.jitterBufferMs))return null;
  const cap=Math.max(2,Math.min(25,ceiling));
  const congested=s.recentLossPct!>3||s.jitterBufferMs!>120||(s.rttMs??0)>300;
  this.stable=congested?0:this.stable+1;
  if(now-this.changed<12000)return null;
  let next=Math.min(this.target,cap);
  if(congested)next=Math.max(2,Math.floor(next*.75));
  else if(this.stable>=20){next=Math.min(cap,next+1);this.stable=0;}
  if(next===this.target)return null;
  this.target=next;this.changed=now;return next;
 }
}
