// Jembatan Desktop (Tauri / Electron / Browser Demo)
//
// Menginisialisasi `window.xydesk` secara otomatis bila berjalan di dalam Tauri
// (menggunakan runtime invoke Tauri v2) atau mempertahankan bridge preload
// bila berjalan di Electron. Jika dibuka di browser biasa, `window.xydesk`
// tetap undefined sehingga mode DEMO aktif.

if (typeof window !== 'undefined') {
  const win = window as any;
  const tauriInternals = win.__TAURI_INTERNALS__ || win.__TAURI__?.core;

  if (tauriInternals && typeof tauriInternals.invoke === 'function' && !win.xydesk) {
    const invoke = tauriInternals.invoke.bind(tauriInternals);
    win.xydesk = {
      getStatus: () => invoke('get_status'),
      runAction: (req: any) => invoke('run_action', { req }),
      getLogs: () => invoke('get_logs'),
      getInfo: () => invoke('get_info'),
      getAutostart: () => invoke('get_autostart'),
      setAutostart: (enable: boolean) => invoke('set_autostart', { enable }),
      restartEngine: () => invoke('restart_engine'),
      setHint: (hint: any) => invoke('set_hint', { hint }),
      authSession: () => invoke('auth_session'),
      authGoogle: () => invoke('auth_google'),
      authEmailRequest: (email: string, name?: string) =>
        invoke('auth_email_request', { email, name }),
      authEmailVerify: (email: string, otp: string, name?: string) =>
        invoke('auth_email_verify', { email, otp, name }),
      authLogout: () => invoke('auth_logout'),
      checkUpdate: () => invoke('check_update'),
      downloadUpdate: () => invoke('download_update'),
      installUpdate: (path: string) => invoke('install_update', { path }),
      checkDriversStatus: () => invoke('check_drivers_status'),
      installDriver: (driverType: string) => invoke('install_driver', { driverType }),
    };
  }
}

export {};
