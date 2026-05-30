const { execFile } = require("node:child_process");
const path = require("node:path");

function execGit(cwd, args) {
  return new Promise((resolve, reject) => {
    execFile("git", args, { cwd, timeout: 45000 }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error((stderr || error.message).trim()));
        return;
      }
      resolve(stdout);
    });
  });
}

async function getGitInfo(sourceRoot) {
  const fs = require("node:fs/promises");
  const gitDir = path.join(sourceRoot, ".git");
  try {
    await fs.access(gitDir);
  } catch {
    return { isGit: false, branch: "", commit: "", dirty: false };
  }

  const branch = await execGit(sourceRoot, ["rev-parse", "--abbrev-ref", "HEAD"]).catch(() => "");
  const commit = await execGit(sourceRoot, ["rev-parse", "--short", "HEAD"]).catch(() => "");
  const status = await execGit(sourceRoot, ["status", "--porcelain"]).catch(() => "");
  return {
    isGit: true,
    branch: branch.trim(),
    commit: commit.trim(),
    dirty: status.trim().length > 0
  };
}

async function pullSource(sourceRoot) {
  const output = await execGit(sourceRoot, ["pull", "--ff-only"]);
  return output.trim();
}

module.exports = { execGit, getGitInfo, pullSource };
