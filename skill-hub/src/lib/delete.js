const fs = require("node:fs/promises");
const path = require("node:path");
const { listSkillDirectories, compareSkillToTarget, normalizeTargets } = require("./scan");

async function deleteSkills({ sourceRoot, targets, skillIds = [], targetIds = [] } = {}) {
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

      if (comparison.status === "missing") {
        results.push({ skillId: skill.id, targetId: target.id, status: "missing", path: targetSkillPath });
        continue;
      }

      if (comparison.status === "conflict") {
        results.push({ skillId: skill.id, targetId: target.id, status: "skipped_conflict", path: targetSkillPath });
        continue;
      }

      await fs.rm(targetSkillPath, { recursive: true, force: true });
      results.push({ skillId: skill.id, targetId: target.id, status: "deleted", path: targetSkillPath });
    }
  }

  return results;
}

module.exports = { deleteSkills };
