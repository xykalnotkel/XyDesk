// Bridge ke Tauri / Electron bridge jika ada
import { invoke } from '@tauri-apps/api/core';

export function setupBridge() {
  if (typeof window !== 'undefined') {
    if (!window.xydesk) {
      window.xydesk = {
        getStatus: () => invoke('get_status'),
        getInfo: () => invoke('get_info'),
        getConfig: () => invoke('get_config'),
        saveConfig: (cfg: any) => invoke('save_config', { cfg }),
        stopSession: () => invoke('stop_session'),
        showWindow: () => invoke('show_window'),
        hideWindow: () => invoke('hide_window'),
        authGoogleLogin: () => invoke('auth_google_login'),
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
}
