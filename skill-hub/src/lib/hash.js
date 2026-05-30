const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const { isExcludedName } = require("./config");

async function hashDirectory(dirPath) {
  const files = await collectFiles(dirPath, dirPath);
  const hash = crypto.createHash("sha256");
  for (const file of files.sort((a, b) => a.relative.localeCompare(b.relative))) {
    hash.update(file.relative);
    hash.update("\0");
    hash.update(await fs.readFile(file.absolute));
    hash.update("\0");
  }
  return hash.digest("hex");
}

async function collectFiles(root, current) {
  const entries = await fs.readdir(current, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (isExcludedName(entry.name)) continue;
    const absolute = path.join(current, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectFiles(root, absolute));
    } else if (entry.isFile()) {
      files.push({
        absolute,
        relative: path.relative(root, absolute).split(path.sep).join("/")
      });
    }
  }

  return files;
}

module.exports = { hashDirectory, collectFiles };
