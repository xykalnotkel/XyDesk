/** Dipanggil langsung dari gesture. Layout viewport tidak bergantung pada API ini. */
export async function enterSessionFullscreen(surface: HTMLElement): Promise<boolean> {
  if (!surface.requestFullscreen) return false;
  try {
    await surface.requestFullscreen();
    return document.fullscreenElement === surface;
  } catch {
    return false;
  }
}

export async function leaveSessionFullscreen(surface: HTMLElement | null): Promise<void> {
  if (!surface || document.fullscreenElement !== surface) return;
  try { await document.exitFullscreen(); } catch { /* Browser mungkin sudah keluar. */ }
}

/** Klik Konek: minta fullscreen ketika aktivasi pengguna masih tersedia. */
export async function enterSessionLandscape(surface:HTMLElement,isCurrent:()=>boolean=()=>true):Promise<'landscape'|'fullscreen'|'unavailable'|'cancelled'> {
  const entered=await enterSessionFullscreen(surface);
  if(!isCurrent()){
    if(entered)await leaveSessionFullscreen(surface);
    return 'cancelled';
  }
  if(!entered)return 'unavailable';
  const orientation=screen.orientation as ScreenOrientation & {lock?:(mode:string)=>Promise<void>};
  if(!orientation?.lock)return 'fullscreen';
  try {await orientation.lock('landscape');return 'landscape';}
  catch{return 'fullscreen';}
}
