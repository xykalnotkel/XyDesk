/** Advertise only a decoder level accepted by the browser's capability probe. */
export async function receiverH264Level():Promise<string>{
  if(!navigator.mediaCapabilities?.decodingInfo)return '1f';
  for(const [level,width,height,framerate] of [['33',4096,2160,15],['28',1920,1080,30]] as const){
    try{const support=await navigator.mediaCapabilities.decodingInfo({type:'webrtc',video:{contentType:`video/H264;profile-level-id=42e0${level};packetization-mode=1`,width,height,bitrate:14000000,framerate}});if(support.supported)return level;}catch{/* Legacy browsers remain at their original SDP level. */}
  }
  return '1f';
}
export function offerWithH264Level(sdp:string,level:string):string{
  if(!['28','33'].includes(level))return sdp;
  return sdp.replace(/(profile-level-id=(?:42e0|4200))1f/gi,`$1${level}`);
}
