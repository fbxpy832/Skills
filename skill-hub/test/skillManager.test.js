const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  scan,
  syncSkills,
  deleteSkills,
  hashDirectory
} = require("../src/lib/skillManager");

async function makeTempRoot() {
  return fs.mkdtemp(path.join(os.tmpdir(), "skill-hub-"));
}

async function writeSkill(root, name, body = "content") {
  const dir = path.join(root, name);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, "SKILL.md"), `---\nname: ${name}\ndescription: Demo skill\n---\n\n# ${name}\n${body}\n`);
  await fs.writeFile(path.join(dir, "notes.md"), body);
  return dir;
}

test("scan discovers source skills and target status", async () => {
  const root = await makeTempRoot();
  const targetRoot = path.join(root, "target");
  await writeSkill(root, "alpha");

  const result = await scan({
    sourceRoot: root,
    targets: [{ id: "codex", name: "Codex", path: targetRoot }]
  });

  assert.equal(result.skills.length, 1);
  assert.equal(result.skills[0].id, "alpha");
  assert.equal(result.skills[0].targets.codex.status, "missing");
});

test("sync copies skills, excludes sensitive files, and reports synced", async () => {
  const root = await makeTempRoot();
  const targetRoot = path.join(root, "target");
  const skillDir = await writeSkill(root, "alpha");
  await fs.writeFile(path.join(skillDir, ".env"), "TOKEN=secret");

  const results = await syncSkills({
    sourceRoot: root,
    targets: [{ id: "codex", name: "Codex", path: targetRoot }],
    skillIds: ["alpha"],
    targetIds: ["codex"]
  });

  assert.equal(results[0].status, "synced");
  assert.equal(await fs.readFile(path.join(targetRoot, "alpha", "notes.md"), "utf8"), "content");
  await assert.rejects(fs.readFile(path.join(targetRoot, "alpha", ".env"), "utf8"));

  const after = await scan({
    sourceRoot: root,
    targets: [{ id: "codex", name: "Codex", path: targetRoot }]
  });
  assert.equal(after.skills[0].targets.codex.status, "synced");
});

test("sync backs up an outdated target before replacing it", async () => {
  const root = await makeTempRoot();
  const targetRoot = path.join(root, "target");
  await writeSkill(root, "alpha", "new");
  await writeSkill(targetRoot, "alpha", "old");

  const beforeHash = await hashDirectory(path.join(targetRoot, "alpha"));
  const results = await syncSkills({
    sourceRoot: root,
    targets: [{ id: "codex", name: "Codex", path: targetRoot }],
    skillIds: ["alpha"],
    targetIds: ["codex"]
  });

  assert.equal(results[0].status, "synced");
  assert.ok(results[0].backupPath.includes(".skill-hub-backups"));
  assert.equal(await hashDirectory(results[0].backupPath), beforeHash);
  assert.equal(await fs.readFile(path.join(targetRoot, "alpha", "notes.md"), "utf8"), "new");
});

test("delete removes selected skills from selected targets without removing source", async () => {
  const root = await makeTempRoot();
  const targetRoot = path.join(root, "target");
  await writeSkill(root, "alpha", "source");
  await writeSkill(targetRoot, "alpha", "installed");

  const results = await deleteSkills({
    sourceRoot: root,
    targets: [{ id: "codex", name: "Codex", path: targetRoot }],
    skillIds: ["alpha"],
    targetIds: ["codex"]
  });

  assert.equal(results[0].status, "deleted");
  assert.equal(await fs.readFile(path.join(root, "alpha", "notes.md"), "utf8"), "source");
  await assert.rejects(fs.readFile(path.join(targetRoot, "alpha", "SKILL.md"), "utf8"));
});

test("delete skips target folders that are not skill folders", async () => {
  const root = await makeTempRoot();
  const targetRoot = path.join(root, "target");
  await writeSkill(root, "alpha", "source");
  await fs.mkdir(path.join(targetRoot, "alpha"), { recursive: true });
  await fs.writeFile(path.join(targetRoot, "alpha", "notes.md"), "not a skill");

  const results = await deleteSkills({
    sourceRoot: root,
    targets: [{ id: "codex", name: "Codex", path: targetRoot }],
    skillIds: ["alpha"],
    targetIds: ["codex"]
  });

  assert.equal(results[0].status, "skipped_conflict");
  assert.equal(await fs.readFile(path.join(targetRoot, "alpha", "notes.md"), "utf8"), "not a skill");
});
