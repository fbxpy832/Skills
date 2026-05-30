const fs = require("node:fs/promises");
const path = require("node:path");
const { isExcludedName, expandHome } = require("./config");
const { hashDirectory } = require("./hash");
const { getGitInfo } = require("./git");

async function listSkillDirectories(sourceRoot) {
  const entries = await fs.readdir(sourceRoot, { withFileTypes: true });
  const skills = [];

  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
    if (isExcludedName(entry.name)) continue;

    const skillPath = path.join(sourceRoot, entry.name);
    const skillFile = path.join(skillPath, "SKILL.md");
    try {
      await fs.access(skillFile);
    } catch {
      continue;
    }

    const h = await hashDirectory(skillPath);
    const metadata = await readSkillMetadata(skillFile);
    skills.push({
      id: entry.name,
      name: metadata.name || entry.name,
      description: metadata.description || "",
      path: skillPath,
      hash: h
    });
  }

  return skills.sort((a, b) => a.name.localeCompare(b.name));
}

async function readSkillMetadata(skillFile) {
  const content = await fs.readFile(skillFile, "utf8");
  if (!content.startsWith("---")) return {};
  const end = content.indexOf("\n---", 3);
  if (end === -1) return {};

  const frontmatter = content.slice(3, end).split(/\r?\n/);
  const metadata = {};
  for (const line of frontmatter) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) continue;
    metadata[match[1]] = match[2].replace(/^["']|["']$/g, "");
  }
  return metadata;
}

async function compareSkillToTarget(skill, target) {
  const targetSkillPath = path.join(target.path, skill.id);
  try {
    await fs.access(targetSkillPath);
  } catch {
    return { targetId: target.id, status: "missing", path: targetSkillPath, hash: "" };
  }

  try {
    await fs.access(path.join(targetSkillPath, "SKILL.md"));
  } catch {
    return { targetId: target.id, status: "conflict", path: targetSkillPath, hash: "" };
  }

  const targetHash = await hashDirectory(targetSkillPath);
  return {
    targetId: target.id,
    status: targetHash === skill.hash ? "synced" : "outdated",
    path: targetSkillPath,
    hash: targetHash
  };
}

function normalizeTargets(targets) {
  return targets.map((target) => ({
    id: target.id,
    name: target.name,
    path: expandHome(target.path)
  }));
}

async function scan({ sourceRoot, targets } = {}) {
  const { DEFAULT_SOURCE_ROOT, DEFAULT_TARGETS, getDefaults } = require("./config");
  const src = sourceRoot || DEFAULT_SOURCE_ROOT;
  const tgts = targets || DEFAULT_TARGETS;
  const normalizedTargets = normalizeTargets(tgts);
  const skills = await listSkillDirectories(src);
  const git = await getGitInfo(src);

  for (const skill of skills) {
    skill.targets = {};
    for (const target of normalizedTargets) {
      skill.targets[target.id] = await compareSkillToTarget(skill, target);
    }
  }

  return {
    sourceRoot: src,
    git,
    targets: normalizedTargets,
    skills
  };
}

module.exports = {
  listSkillDirectories,
  readSkillMetadata,
  compareSkillToTarget,
  normalizeTargets,
  scan
};
