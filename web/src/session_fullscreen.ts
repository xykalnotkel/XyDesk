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
