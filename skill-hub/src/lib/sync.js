const fs = require("node:fs/promises");
const path = require("node:path");
const { isExcludedName } = require("./config");
const { listSkillDirectories, compareSkillToTarget, normalizeTargets } = require("./scan");

async function syncSkills({ sourceRoot, targets, skillIds = [], targetIds = [], force = false } = {}) {
  if (!skillIds.length) throw new Error("No skills selected.");
  if (!targetIds.length) throw new Error("No targets selected.");

  const normalizedTargets = normalizeTargets(targets).filter((t) => targetIds.includes(t.id));
  if (!normalizedTargets.length) throw new Error("No matching target directories selected.");

  const skills = await listSkillDirectories(sourceRoot);
  const selectedSkills = skills.filter((s) => skillIds.includes(s.id));
  if (!selectedSkills.length) throw new Error("No selected skills were found in the source root.");

  const results = [];
  for (const skill of selectedSkills) {
    for (const target of normalizedTargets) {
      const targetSkillPath = path.join(target.path, skill.id);
      const comparison = await compareSkillToTarget(skill, target);

      if (comparison.status === "conflict" && !force) {
        results.push({ skillId: skill.id, targetId: target.id, status: "skipped_conflict", path: targetSkillPath });
        continue;
      }

      if (comparison.status === "synced") {
        results.push({ skillId: skill.id, targetId: target.id, status: "already_synced", path: targetSkillPath });
        continue;
      }

      const backupPath = await backupExistingTarget(targetSkillPath);
      await fs.mkdir(target.path, { recursive: true });
      await fs.rm(targetSkillPath, { recursive: true, force: true });
      await copyDirectorySafe(skill.path, targetSkillPath);

      results.push({
        skillId: skill.id,
        targetId: target.id,
        status: "synced",
        path: targetSkillPath,
        backupPath
      });
    }
  }

  return results;
}

async function backupExistingTarget(targetSkillPath) {
  try {
    await fs.access(targetSkillPath);
  } catch {
    return "";
  }
  const parent = path.dirname(targetSkillPath);
  const name = path.basename(targetSkillPath);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const backupRoot = path.join(parent, ".skill-hub-backups");
  const backupPath = path.join(backupRoot, `${name}-${stamp}`);
  await fs.mkdir(backupRoot, { recursive: true });
  await fs.cp(targetSkillPath, backupPath, { recursive: true, force: false });
  return backupPath;
}

async function copyDirectorySafe(source, destination) {
  await fs.mkdir(destination, { recursive: true });
  const entries = await fs.readdir(source, { withFileTypes: true });

  for (const entry of entries) {
    if (isExcludedName(entry.name)) continue;
    const from = path.join(source, entry.name);
    const to = path.join(destination, entry.name);
    if (entry.isDirectory()) {
      await copyDirectorySafe(from, to);
    } else if (entry.isFile()) {
      await fs.copyFile(from, to);
    }
  }
}

module.exports = { syncSkills, backupExistingTarget, copyDirectorySafe };
