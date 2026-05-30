const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("skillHub", {
  scan: (options) => ipcRenderer.invoke("skill-hub:scan", options),
  sync: (options) => ipcRenderer.invoke("skill-hub:sync", options),
  delete: (options) => ipcRenderer.invoke("skill-hub:delete", options),
  pullSource: (sourceRoot) => ipcRenderer.invoke("skill-hub:pull-source", sourceRoot),
  getDefaults: () => ipcRenderer.invoke("skill-hub:get-defaults")
});
