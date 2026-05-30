const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");

test("renderer calls the sync API exposed by preload", async () => {
  const preload = await fs.readFile(path.join(root, "src", "preload.js"), "utf8");
  const renderer = await fs.readFile(path.join(root, "src", "renderer", "app.js"), "utf8");

  assert.match(preload, /sync:\s*\(options\)\s*=>\s*ipcRenderer\.invoke\("skill-hub:sync", options\)/);
  assert.match(renderer, /skillHub\.sync\(\{/);
  assert.doesNotMatch(renderer, /skillHub\.syncSkills/);
});

test("renderer clears the loading guard before refreshing after sync", async () => {
  const renderer = await fs.readFile(path.join(root, "src", "renderer", "app.js"), "utf8");
  assert.match(renderer, /async function syncSelected\(\)[\s\S]*state\.loading = false;\s*await refreshScan\(\);/);
});

test("renderer calls the delete API exposed by preload", async () => {
  const preload = await fs.readFile(path.join(root, "src", "preload.js"), "utf8");
  const renderer = await fs.readFile(path.join(root, "src", "renderer", "app.js"), "utf8");
  const html = await fs.readFile(path.join(root, "src", "renderer", "index.html"), "utf8");

  assert.match(preload, /delete:\s*\(options\)\s*=>\s*ipcRenderer\.invoke\("skill-hub:delete", options\)/);
  assert.match(renderer, /skillHub\.delete\(\{/);
  assert.match(renderer, /confirm\(/);
  assert.match(html, /id="btnDeleteSelected"/);
});
