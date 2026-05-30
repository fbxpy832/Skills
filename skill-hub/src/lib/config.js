const path = require("node:path");
const os = require("node:os");

const DEFAULT_SOURCE_ROOT = "/Users/xpy/Documents/RichardHub/Git";

const DEFAULT_TARGETS = [
  { id: "codex", name: "Codex", path: path.join(os.homedir(), ".codex", "skills") },
  { id: "claude", name: "Claude Code", path: path.join(os.homedir(), ".claude", "skills") },
  { id: "opencode", name: "OpenCode", path: path.join(os.homedir(), ".config", "opencode", "skills") },
  { id: "hermes", name: "Hermes Agent", path: path.join(os.homedir(), ".hermes", "skills") }
];

const EXCLUDED_NAMES = new Set([
  ".git",
  ".hg",
  ".svn",
  ".DS_Store",
  ".env",
  ".env.local",
  ".env.production",
  "node_modules",
  "__pycache__",
  ".venv",
  "venv",
  "dist",
  "build",
  ".codex-opencode",
  ".superpowers"
]);

const EXCLUDED_EXTENSIONS = new Set([
  ".pem",
  ".key",
  ".p12",
  ".pfx",
  ".crt",
  ".cer",
  ".sqlite",
  ".db"
]);

function getDefaults() {
  return {
    sourceRoot: DEFAULT_SOURCE_ROOT,
    targets: DEFAULT_TARGETS
  };
}

function isExcludedName(name) {
  const lower = name.toLowerCase();
  if (EXCLUDED_NAMES.has(name) || EXCLUDED_NAMES.has(lower)) return true;
  if (lower.includes("cookie")) return true;
  if (lower.includes("secret")) return true;
  if (lower.endsWith(".log")) return true;
  return EXCLUDED_EXTENSIONS.has(path.extname(lower));
}

function expandHome(value) {
  if (!value) return value;
  if (value === "~") return os.homedir();
  if (value.startsWith("~/")) return path.join(os.homedir(), value.slice(2));
  return value;
}

module.exports = {
  DEFAULT_SOURCE_ROOT,
  DEFAULT_TARGETS,
  EXCLUDED_NAMES,
  EXCLUDED_EXTENSIONS,
  getDefaults,
  isExcludedName,
  expandHome
};
