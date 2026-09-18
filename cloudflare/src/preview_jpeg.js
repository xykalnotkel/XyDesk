// Header-only bounds check before the browser allocates decoded pixels.
export function validPreviewJpeg(raw) {
  if(typeof raw!=='string'||!raw.startsWith('\xff\xd8')||!raw.endsWith('\xff\xd9'))return false;
  let i=2,shape=false;
  while(i<raw.length-2){
    if(raw.charCodeAt(i++)!==255)return false;
    while(raw.charCodeAt(i)===255)i++;
    const marker=raw.charCodeAt(i++);
    if(marker===0xda)return shape;
    if(marker===0xd9)return false;
    const length=(raw.charCodeAt(i)<<8)|raw.charCodeAt(i+1);
    if(length<2||i+length>raw.length)return false;
    if([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker)){
      if(shape||![0xc0,0xc2].includes(marker)||length<8)return false;
      const height=(raw.charCodeAt(i+3)<<8)|raw.charCodeAt(i+4),width=(raw.charCodeAt(i+5)<<8)|raw.charCodeAt(i+6);
      if(raw.charCodeAt(i+2)!==8||width<1||height<1||width>1920||height>1080)return false;
      shape=true;
    }
    i+=length;
  }
  return false;
}
