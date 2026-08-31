// Preload XyDesk Desktop — jembatan minimal renderer → proses utama.
// Renderer hanya melihat 4 fungsi; semua rahasia (token control, token
// signaling) tinggal di proses utama.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('xydesk', {
  getStatus: () => ipcRenderer.invoke('status'),
  runAction: (req) => ipcRenderer.invoke('action', req),
  getLogs: () => ipcRenderer.invoke('logs'),
  getInfo: () => ipcRenderer.invoke('info'),
});
