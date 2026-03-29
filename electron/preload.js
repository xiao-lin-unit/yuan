const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  ping: () => ipcRenderer.send('ping'),
  onPong: (callback) => ipcRenderer.on('pong', callback)
})
