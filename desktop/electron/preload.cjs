// Preload XyDesk Desktop — jembatan minimal renderer → proses utama.
// Semua rahasia tinggal di proses utama: token control, token signaling, dan
// token sesi login. Karena itu auth di sini hanya mengembalikan status masuk
// dan identitas pengguna — renderer tidak pernah memegang token, dan tidak ada
// satu pun fungsi yang bisa memintanya.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('xydesk', {
  getStatus: () => ipcRenderer.invoke('status'),
  runAction: (req) => ipcRenderer.invoke('action', req),
  getLogs: () => ipcRenderer.invoke('logs'),
  getInfo: () => ipcRenderer.invoke('info'),
  getAutostart: () => ipcRenderer.invoke('autostart:get'),
  setAutostart: (enable) => ipcRenderer.invoke('autostart:set', enable),
  restartEngine: () => ipcRenderer.invoke('engine:restart'),
  setHint: (hint) => ipcRenderer.invoke('window:hint', hint),
  // ── Login ──
  // authSession() → { masuk, user, metode, exp, tersimpan }; tanpa token.
  authSession: () => ipcRenderer.invoke('auth:session'),
  // authGoogle() membuka browser sistem; proses utama yang menangkap code di
  // loopback dan menukarnya ke Worker. Mengembalikan { ok, sesi } atau
  // { ok:false, error, message } — tidak pernah melempar.
  authGoogle: () => ipcRenderer.invoke('auth:google'),
  authEmailRequest: (email, name) => ipcRenderer.invoke('auth:email:request', email, name),
  authEmailVerify: (email, otp, name) => ipcRenderer.invoke('auth:email:verify', email, otp, name),
  authLogout: () => ipcRenderer.invoke('auth:logout'),
});
