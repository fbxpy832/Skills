#!/usr/bin/env node
// index.js — Deep Research Plugin: OpenCode adapter entry point
// Multi-host distribution package v1.0
// Host adapter for OpenCode CLI/TUI

import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { spawn } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Plugin root directory (where package.json lives)
const PLUGIN_DIR = __dirname;

function runRunner(mode, taskFile, outputDir, options = {}) {
  const { dryRun = false, sequential = false } = options;
  const runnerScript = resolve(PLUGIN_DIR, 'scripts', 'opencode-research-runner.sh');
  const projectDir = options.projectDir || process.cwd();

  const args = [runnerScript, mode, taskFile, outputDir, projectDir];
  if (dryRun) args.push('--dry-run');
  if (sequential) args.push('--sequential');

  return new Promise((resolve, reject) => {
    const proc = spawn('/bin/bash', args, {
      cwd: PLUGIN_DIR,
      env: { ...process.env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (d) => { stdout += d.toString(); });
    proc.stderr.on('data', (d) => { stderr += d.toString(); });

    proc.on('close', (code) => {
      resolve({
        command: ['bash', ...args].join(' '),
        exit_code: code,
        output_dir: outputDir,
        stdout: stdout.slice(-2000),
        stderr: stderr.slice(-2000),
      });
    });

    proc.on('error', (err) => {
      reject({ command: ['bash', ...args].join(' '), exit_code: -1, error: err.message });
    });
  });
}

// ── Plugin exports ──────────────────────────────────────────────

export function activate(context) {
  return {
    name: 'deep-research',
    version: context.package?.version || '1.0.0',

    tools: [
      {
        name: 'deep_research_run',
        description: 'Run a Deep Research task using the multi-stage agent pipeline. Generates report, events, and artifacts.',
        inputSchema: {
          type: 'object',
          properties: {
            mode: {
              type: 'string',
              enum: ['high_quality', 'balanced', 'long_context', 'cost_saving', 'draft_fast'],
              description: 'Research quality mode',
            },
            task: { type: 'string', description: 'Research task description (written to temp file)' },
            outputDir: { type: 'string', description: 'Output directory for artifacts' },
            dryRun: { type: 'boolean', description: 'Dry run (no agent invocation)', default: false },
            sequential: { type: 'boolean', description: 'Run stages sequentially', default: false },
          },
          required: ['mode', 'task', 'outputDir'],
        },

        async execute({ mode, task, outputDir, dryRun = false, sequential = false }) {
          const { writeFileSync, mkdirSync, readFileSync, existsSync } = await import('node:fs');
          const { join } = await import('node:path');

          mkdirSync(outputDir, { recursive: true });
          const taskFile = join(outputDir, 'task.md');
          writeFileSync(taskFile, task);

          const result = await runRunner(mode, taskFile, outputDir, {
            dryRun,
            sequential,
            projectDir: process.cwd(),
          });

          let runSummary = '';
          const summaryFile = join(outputDir, 'run-summary.md');
          if (existsSync(summaryFile)) {
            runSummary = readFileSync(summaryFile, 'utf-8').slice(0, 2000);
          }

          return {
            content: [
              { type: 'text', text: `## Deep Research Run Complete\n\n**Mode:** ${mode}\n**Output:** ${outputDir}\n**Exit code:** ${result.exit_code}\n\n### Summary\n${runSummary || '(no summary)'}\n\n### Runner Output\n\`\`\`\n${result.stdout.slice(-1000)}\n\`\`\`` },
            ],
          };
        },
      },
    ],

    commands: [],
    hooks: [],
  };
}
