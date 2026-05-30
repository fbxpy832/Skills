const state = {
  sourceRoot: "",
  targets: [],
  skills: [],
  git: null,
  selectedSkillIds: new Set(),
  selectedTargetIds: new Set(),
  loading: false
};

const $ = (id) => document.getElementById(id);
const $sourcePath = $("sourcePath");
const $skillList = $("skillList");
const $targetGrid = $("targetGrid");
const $logOutput = $("logOutput");
const $btnRefresh = $("btnRefresh");
const $btnPull = $("btnPull");
const $btnSelectAll = $("btnSelectAll");
const $btnSelectNone = $("btnSelectNone");
const $btnSyncSelected = $("btnSyncSelected");
const $btnDeleteSelected = $("btnDeleteSelected");
const $btnClearLog = $("btnClearLog");
const $gitInfo = $("gitInfo");
const $chkForce = $("chkForce");
const $statusIndicator = $("statusIndicator");
const $selectedCount = $("selectedCount");

function setStatus(text, className) {
  $statusIndicator.textContent = text;
  $statusIndicator.className = "header-status " + (className || "");
}

function updateSelectedCount() {
  const nSkills = state.selectedSkillIds.size;
  const nTargets = state.selectedTargetIds.size;
  if (nSkills === 0 && nTargets === 0) {
    $selectedCount.textContent = "";
  } else {
    $selectedCount.textContent = `${nSkills} skill${nSkills !== 1 ? "s" : ""} / ${nTargets} target${nTargets !== 1 ? "s" : ""} selected`;
  }
}

function log(message, className = "") {
  const line = document.createElement("div");
  line.className = `log-line ${className}`;
  line.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
  $logOutput.appendChild(line);
  $logOutput.scrollTop = $logOutput.scrollHeight;
}

function clearLog() {
  $logOutput.innerHTML = "";
}

function statusInfo(status) {
  switch (status) {
    case "synced": return { css: "synced", label: "synced" };
    case "missing": return { css: "missing", label: "missing" };
    case "outdated": return { css: "outdated", label: "outdated" };
    case "conflict": return { css: "conflict", label: "conflict" };
    default: return { css: "missing", label: status };
  }
}

function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function setLoading(loading, buttonStates = {}) {
  state.loading = loading;
  for (const [btn, config] of Object.entries(buttonStates)) {
    if (config.disabled !== undefined) btn.disabled = config.disabled;
    if (config.text) btn.textContent = config.text;
  }
}

function logResults(results, verbMap) {
  for (const r of results) {
    const msg = verbMap[r.status];
    if (msg) {
      log(`${r.skillId} → ${r.targetId}: ${msg.label}`, msg.className || "");
    }
  }
}

async function loadDefaults() {
  try {
    const defaults = await skillHub.getDefaults();
    state.sourceRoot = defaults.sourceRoot;
    state.targets = defaults.targets;
    state.selectedTargetIds = new Set(defaults.targets.map((t) => t.id));
    $sourcePath.value = state.sourceRoot;
  } catch (err) {
    log(`Failed to load defaults: ${err.message}`, "log-error");
  }
}

async function refreshScan() {
  if (state.loading) return;
  setStatus("Scanning...", "scanning");
  setLoading(true, {
    [$btnRefresh]: { disabled: true, text: "Scanning..." }
  });

  const src = $sourcePath.value.trim();
  if (!src) {
    log("Source path is empty.", "log-error");
    setLoading(false, {
      [$btnRefresh]: { disabled: false, text: "Scan" }
    });
    return;
  }
  state.sourceRoot = src;

  try {
    const result = await skillHub.scan({
      sourceRoot: state.sourceRoot,
      targets: state.targets
    });

    state.skills = result.skills;
    state.git = result.git;
    state.selectedSkillIds.clear();

    log(`Scan complete: ${result.skills.length} skill(s) found.`);
    renderGitInfo();
    renderSkills();
    renderTargets();
    updateActionButtons();
  } catch (err) {
    log(`Scan error: ${err.message}`, "log-error");
    $skillList.innerHTML = `<div class="empty-state">Scan failed: ${err.message}</div>`;
    $targetGrid.innerHTML = `<div class="empty-state">No data.</div>`;
  } finally {
    setLoading(false, {
      [$btnRefresh]: { disabled: false, text: "Scan" }
    });
    setStatus("Idle", "");
  }
}

async function pullSource() {
  if (state.loading) return;
  setStatus("Pulling...", "scanning");
  setLoading(true, {
    [$btnPull]: { disabled: true, text: "Pulling..." }
  });

  try {
    const output = await skillHub.pullSource(state.sourceRoot);
    log(`Git pull: ${output || "Already up to date."}`, "log-success");
    state.loading = false;
    await refreshScan();
  } catch (err) {
    log(`Git pull failed: ${err.message}`, "log-error");
  } finally {
    setLoading(false, {
      [$btnPull]: { disabled: false, text: "Pull" }
    });
    setStatus("Idle", "");
  }
}

async function syncSelected() {
  if (state.loading || state.selectedSkillIds.size === 0 || state.selectedTargetIds.size === 0) return;
  setStatus("Syncing...", "scanning");
  setLoading(true, {
    [$btnSyncSelected]: { disabled: true, text: "Syncing..." }
  });

  const skillIds = Array.from(state.selectedSkillIds);
  const targetIds = Array.from(state.selectedTargetIds);

  try {
    const results = await skillHub.sync({
      sourceRoot: state.sourceRoot,
      targets: state.targets,
      skillIds,
      targetIds,
      force: $chkForce.checked
    });

    logResults(results, {
      synced: { label: "synced", className: "log-success" },
      already_synced: { label: "already up to date" },
      skipped_conflict: { label: "skipped (conflict — missing SKILL.md)", className: "log-error" }
    });

    state.loading = false;
    await refreshScan();
  } catch (err) {
    log(`Sync failed: ${err.message}`, "log-error");
  } finally {
    setLoading(false, {
      [$btnSyncSelected]: { disabled: false, text: "Sync Selected" }
    });
    setStatus("Idle", "");
  }
}

async function deleteSelected() {
  if (state.loading || state.selectedSkillIds.size === 0 || state.selectedTargetIds.size === 0) return;

  const skillIds = Array.from(state.selectedSkillIds);
  const targetIds = Array.from(state.selectedTargetIds);
  const message = `Delete ${skillIds.length} selected skill(s) from ${targetIds.length} selected target(s)?\n\nSource skills will not be deleted.`;
  if (!confirm(message)) return;

  setStatus("Deleting...", "scanning");
  setLoading(true, {
    [$btnDeleteSelected]: { disabled: true, text: "Deleting..." }
  });

  try {
    const results = await skillHub.delete({
      sourceRoot: state.sourceRoot,
      targets: state.targets,
      skillIds,
      targetIds
    });

    logResults(results, {
      deleted: { label: "deleted", className: "log-success" },
      missing: { label: "already missing" },
      skipped_conflict: { label: "skipped (conflict — missing SKILL.md)", className: "log-error" }
    });

    state.loading = false;
    await refreshScan();
  } catch (err) {
    log(`Delete failed: ${err.message}`, "log-error");
  } finally {
    setLoading(false, {
      [$btnDeleteSelected]: { disabled: false, text: "Delete Selected" }
    });
    updateActionButtons();
    setStatus("Idle", "");
  }
}

function renderGitInfo() {
  if (!state.git) { $gitInfo.innerHTML = ""; return; }
  let html = "";
  if (state.git.isGit) {
    html += `<span class="branch">${escapeHtml(state.git.branch || "HEAD")}</span>`;
    html += ` <span>@ ${escapeHtml(state.git.commit || "???")}</span>`;
    if (state.git.dirty) html += ` <span class="dirty">(dirty)</span>`;
  } else {
    html = "Not a Git repository";
  }
  $gitInfo.innerHTML = html;
}

function renderSkills() {
  if (!state.skills.length) {
    $skillList.innerHTML = `<div class="empty-state">No skills found in source.</div>`;
    return;
  }

  $skillList.innerHTML = state.skills
    .map(
      (skill) => `
    <label class="skill-item">
      <input type="checkbox" value="${escapeHtml(skill.id)}"
        ${state.selectedSkillIds.has(skill.id) ? "checked" : ""}>
      <div class="skill-meta">
        <span class="skill-name">${escapeHtml(skill.name)}</span>
        <span class="skill-desc">${escapeHtml(skill.description)}</span>
      </div>
    </label>`
    )
    .join("");

  $skillList.querySelectorAll("input[type='checkbox']").forEach((cb) => {
    cb.addEventListener("change", () => {
      if (cb.checked) {
        state.selectedSkillIds.add(cb.value);
      } else {
        state.selectedSkillIds.delete(cb.value);
      }
      updateActionButtons();
    });
  });
}

function renderTargets() {
  if (!state.skills.length) {
    $targetGrid.innerHTML = `<div class="empty-state">No skills to display.</div>`;
    return;
  }

  const targetNames = state.targets.map((t) => t.name);
  let html = `<div class="target-header-row">
    <span class="target-header-label">Skill</span>
    ${targetNames.map((name, index) => {
      const target = state.targets[index];
      const checked = state.selectedTargetIds.has(target.id) ? "checked" : "";
      return `<label class="target-header-col target-toggle">
        <input type="checkbox" value="${escapeHtml(target.id)}" ${checked}>
        <span>${escapeHtml(name)}</span>
      </label>`;
    }).join("")}
  </div>`;

  for (const skill of state.skills) {
    html += `<div class="target-row">
      <span class="target-skill-name" title="${escapeHtml(skill.id)}">${escapeHtml(skill.name)}</span>`;

    for (const target of state.targets) {
      const targetStatus = skill.targets[target.id];
      if (!targetStatus) {
        html += `<div class="target-cell"><span class="status-badge status-missing">—</span></div>`;
      } else {
        const info = statusInfo(targetStatus.status);
        html += `<div class="target-cell"><span class="status-badge status-${info.css}">${info.label}</span></div>`;
      }
    }

    html += `</div>`;
  }

  $targetGrid.innerHTML = html;
  $targetGrid.querySelectorAll(".target-toggle input").forEach((cb) => {
    cb.addEventListener("change", () => {
      if (cb.checked) {
        state.selectedTargetIds.add(cb.value);
      } else {
        state.selectedTargetIds.delete(cb.value);
      }
      updateActionButtons();
    });
  });
}

function updateActionButtons() {
  const disabled = state.selectedSkillIds.size === 0 || state.selectedTargetIds.size === 0;
  $btnSyncSelected.disabled = disabled;
  $btnDeleteSelected.disabled = disabled;
  updateSelectedCount();
}

function selectAll() {
  state.skills.forEach((s) => state.selectedSkillIds.add(s.id));
  renderSkills();
  updateActionButtons();
}

function selectNone() {
  state.selectedSkillIds.clear();
  renderSkills();
  updateActionButtons();
}

$btnRefresh.addEventListener("click", refreshScan);
$btnPull.addEventListener("click", pullSource);
$btnSelectAll.addEventListener("click", selectAll);
$btnSelectNone.addEventListener("click", selectNone);
$btnSyncSelected.addEventListener("click", syncSelected);
$btnDeleteSelected.addEventListener("click", deleteSelected);
$btnClearLog.addEventListener("click", clearLog);

$sourcePath.addEventListener("keydown", (e) => {
  if (e.key === "Enter") refreshScan();
});

(async () => {
  await loadDefaults();
  if (state.sourceRoot) {
    await refreshScan();
  }
})();
