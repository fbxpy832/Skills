import { tool } from "@opencode-ai/plugin";
import { resolve, dirname, join } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { writeFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function runRunner(mode, taskFile, outputDir, options = {}) {
  const { dryRun = false, sequential = false, projectDir } = options;
  const runnerScript = resolve(__dirname, "scripts", "opencode-research-runner.sh");

  const args = [runnerScript, mode, taskFile, outputDir, projectDir || process.cwd()];
  if (dryRun) args.push("--dry-run");
  if (sequential) args.push("--sequential");

  return new Promise((resolve) => {
    const proc = spawn("/bin/bash", args, {
      cwd: __dirname,
      env: { ...process.env },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    proc.stderr.on("data", (d) => { stderr += d.toString(); });
    proc.on("close", (code) => {
      resolve({ command: ["bash", ...args].join(" "), exit_code: code, output_dir: outputDir, stdout: stdout.slice(-2000), stderr: stderr.slice(-2000) });
    });
    proc.on("error", (err) => {
      resolve({ command: ["bash", ...args].join(" "), exit_code: -1, output_dir: outputDir, error: err.message });
    });
  });
}

export const DeepResearchPlugin = async ({ directory, worktree }) => {
  return {
    tool: {
      deep_research_run: tool({
        description: "Run a Deep Research task using the multi-stage agent pipeline. Generates report, events, and artifacts.",
        args: {
          mode: tool.schema.enum(["high_quality", "balanced", "long_context", "cost_saving", "draft_fast"]),
          task: tool.schema.string(),
          outputDir: tool.schema.string(),
          dryRun: tool.schema.boolean().default(false),
          sequential: tool.schema.boolean().default(false),
        },
        async execute(args, context) {
          const { mode, task, outputDir, dryRun = false, sequential = false } = args;
          const { directory } = context;

          mkdirSync(outputDir, { recursive: true });
          const taskFile = join(outputDir, "task.md");
          writeFileSync(taskFile, task);

          const result = await runRunner(mode, taskFile, outputDir, {
            dryRun,
            sequential,
            projectDir: directory,
          });

          let runSummary = "";
          const summaryFile = join(outputDir, "run-summary.md");
          if (existsSync(summaryFile)) {
            runSummary = readFileSync(summaryFile, "utf-8").slice(0, 2000);
          }

          const eventsFile = join(outputDir, "events.ndjson");
          const eventCount = existsSync(eventsFile)
            ? readFileSync(eventsFile, "utf-8").split("\n").filter(Boolean).length
            : 0;

          return `## Deep Research Run Complete

**Mode:** ${mode}
**Output:** ${outputDir}
**Exit code:** ${result.exit_code}
**Events:** ${eventCount}

### Runner Output
\`\`\`
${result.stdout.slice(-1000) || result.stderr.slice(-1000) || "(empty)"}
\`\`\``;
        },
      }),
    },
  };
};
