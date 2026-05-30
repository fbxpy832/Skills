const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");

const {
  scan,
  syncSkills,
  deleteSkills,
  pullSource,
  getDefaults
} = require("./lib/skillManager");

function createWindow() {
  const win = new BrowserWindow({
    width: 960,
    height: 680,
    minWidth: 800,
    minHeight: 500,
    title: "Skill Hub",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  win.loadFile(path.join(__dirname, "renderer", "index.html"));
}

ipcMain.handle("skill-hub:scan", async (_event, options) => {
  return scan(options);
});

ipcMain.handle("skill-hub:sync", async (_event, options) => {
  return syncSkills(options);
});

ipcMain.handle("skill-hub:delete", async (_event, options) => {
  return deleteSkills(options);
});

ipcMain.handle("skill-hub:pull-source", async (_event, sourceRoot) => {
  return pullSource(sourceRoot);
});

ipcMain.handle("skill-hub:get-defaults", async () => {
  return getDefaults();
});

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
