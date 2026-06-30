#!/usr/bin/env python3
"""
extract_candidates.py - 从 rollout summaries 自动抽取候选记忆

用途:
  从 ~/.codex/memories/rollout_summaries/ 读取近期总结，
  提取可复用的知识点、偏好、命令，写入 Codex-Input/pending/。

用法:
  python3 extract_candidates.py
  python3 extract_candidates.py --dry-run
  python3 extract_candidates.py --days 7
"""
import sys
import os
import re
import argparse
from pathlib import Path
from datetime import datetime, timedelta

AUTO_DIR = Path.home() / ".codex" / "memory-automation"
LOG_DIR = AUTO_DIR / "logs"
ROLLOUT_DIR = Path.home() / ".codex" / "memories" / "rollout_summaries"

# Obsidian vault
VAULT = (
    Path.home()
    / "Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"
)
PENDING_DIR = VAULT / "Codex-Input" / "pending"

# 候选记忆抽取模式（按主题命中触发）
CANDIDATE_PATTERNS = {
    "preference": re.compile(
        r"(?i)(prefer|偏好|喜欢|喜欢用|习惯|always.*use|default to|倾向于)"
    ),
    "knowledge": re.compile(
        r"(?i)(备忘|注意|知识|原理|原因|实际上|本质上|关键是|来源于|源于)"
    ),
    "decision": re.compile(
        r"(?i)(决定|决策|改用|放弃|不再|选.*方案|采用|confirmed|accepted|approved)"
    ),
    "pitfall": re.compile(
        r"(?i)(踩坑|报错|错误|失败|bug|不要|不能|避免|注意.*不|如果.*会.*错)"
    ),
    "procedure": re.compile(
        r"(?i)(步骤|流程|方法|如何|怎样|安装|配置|启用|运行|执行|用法)"
    ),
}

# 不变知识点直接抽取模式
KNOWLEDGE_MARKERS = re.compile(
    r"(?i)(经验|总结|结论|方案|修复|解决|推荐|"
    r"Reusable knowledge|Learnings)"
)

def parse_frontmatter(text: str) -> tuple[dict, str]:
    """解析 YAML frontmatter"""
    fm_re = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
    m = fm_re.match(text)
    if not m:
        return {}, text
    raw = m.group(1)
    body = text[m.end():]
    meta = {}
    for line in raw.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            meta[k.strip()] = v.strip().strip('"').strip("'")
    return meta, body


def extract_section(text: str, section_title: str) -> str | None:
    """抽取 markdown 中的特定 section 内容"""
    pattern = re.compile(
        rf"^##\s+{re.escape(section_title)}\s*\n(.*?)(?=\n##\s|\Z)",
        re.DOTALL | re.MULTILINE,
    )
    m = pattern.search(text)
    return m.group(1).strip() if m else None


def extract_candidates_from_file(filepath: Path) -> list[dict]:
    """从单个 rollout summary 抽取候选记忆"""
    try:
        text = filepath.read_text(errors="replace")
    except Exception as e:
        return []

    meta, body = parse_frontmatter(text)
    candidates = []
    filename = filepath.stem

    # 1. Reusable knowledge section
    rk = extract_section(text, "Reusable knowledge")
    if rk:
        candidates.append({
            "type": "knowledge",
            "source": filename,
            "confidence": "high",
            "content": rk,
        })

    # 2. Learnings section
    for title in ("Learnings", "learnings", "Key learnings"):
        section = extract_section(text, title)
        if section:
            candidates.append({
                "type": "knowledge",
                "source": filename,
                "confidence": "high",
                "content": section,
            })
            break

    # 3. Preference signals section
    ps = extract_section(text, "Preference signals")
    if ps:
        candidates.append({
            "type": "preference",
            "source": filename,
            "confidence": "medium",
            "content": ps,
        })

    # 4. Failures section
    fl = extract_section(text, "Failures")
    if fl:
        candidates.append({
            "type": "pitfall",
            "source": filename,
            "confidence": "high",
            "content": fl,
        })

    # 5. Pattern-based extraction from body
    for cand_type, pattern in CANDIDATE_PATTERNS.items():
        matches = []
        for line in body.splitlines():
            if pattern.search(line) and len(line.strip()) > 20:
                matches.append(line.strip()[:120])
                if len(matches) >= 3:
                    break
        if matches:
            candidates.append({
                "type": cand_type,
                "source": filename,
                "confidence": "low",
                "content": "\n".join(f"- {m}" for m in matches),
            })

    # 6. Key steps section
    ks = extract_section(text, "Key steps")
    if ks:
        candidates.append({
            "type": "procedure",
            "source": filename,
            "confidence": "medium",
            "content": ks,
        })

    return candidates


def write_candidate_file(candidate: dict, output_dir: Path, dry_run: bool = False) -> str | None:
    """将候选记忆写入 Obsidian Codex-Input/pending/
    同一个 source 的不同 type 分别写不同文件。
    如果文件名已存在则跳过（幂等）。
    """
    ts = datetime.now().strftime("%Y-%m-%d")
    slug = re.sub(r"[^\w\s-]", "", candidate["source"][:40])
    slug = re.sub(r"[\s_-]+", "-", slug).strip("-")
    fname = f"{ts}-{candidate['type']}-{slug}.md"
    fpath = output_dir / fname

    if fpath.exists():
        # 合并：追加新 candidate 到已有文件
        existing = fpath.read_text()
        extra = (
            f"\n---\n"
            f"type: {candidate['type']}\n"
            f"confidence: {candidate['confidence']}\n"
            f"---\n\n"
            f"## Candidate Memory ({candidate['type']})\n\n"
            f"{candidate['content']}\n\n"
        )
        if dry_run:
            print(f"[DRY-RUN] 合并到: {fpath}")
            return str(fpath)
        fpath.write_text(existing + extra)
        print(f"合并到: {fpath}")
        return str(fpath)

    content = (
        "---\n"
        f'type: {candidate["type"]}\n'
        f'scope: \n'
        f'project: \n'
        f'source: {candidate["source"]}\n'
        f'confidence: {candidate["confidence"]}\n'
        f'status: pending\n'
        f'created_at: {ts}\n'
        f'last_verified: \n'
        "---\n\n"
        f"## Candidate Memory ({candidate['type']})\n\n"
        f"{candidate['content']}\n\n"
        "## Evidence (source)\n\n"
        f"Extracted from: `{candidate['source']}`\n\n"
        "## Suggested Destination\n\n"
        "Codex-Memory/Ground-Truth.md\n"
    )

    if dry_run:
        print(f"[DRY-RUN] 将写入: {fpath}")
        print(content[:200] + "...\n")
        return str(fpath)

    fpath.write_text(content)
    print(f"已写入: {fpath}")
    return str(fpath)


def main():
    parser = argparse.ArgumentParser(
        description="从 rollout summaries 提取候选记忆"
    )
    parser.add_argument(
        "--days", type=int, default=14,
        help="读取最近 N 天的 rollout summary (default: 14)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="只预览，不写入"
    )
    args = parser.parse_args()

    if not ROLLOUT_DIR.is_dir():
        print(f"ERROR: rollout summaries 目录不存在: {ROLLOUT_DIR}", file=sys.stderr)
        return 1

    PENDING_DIR.mkdir(parents=True, exist_ok=True)

    cutoff = datetime.now() - timedelta(days=args.days)
    files = sorted(ROLLOUT_DIR.glob("*.md"))
    recent = [f for f in files if datetime.fromtimestamp(f.stat().st_mtime) > cutoff]

    print(f"扫描 {len(recent)} 个近期 rollout summary ...")

    total_candidates = 0
    written = 0

    for fpath in recent:
        candidates = extract_candidates_from_file(fpath)
        if not candidates:
            continue
        total_candidates += len(candidates)
        for cand in candidates:
            result = write_candidate_file(cand, PENDING_DIR, dry_run=args.dry_run)
            if result:
                written += 1

    print(f"\n完成: {total_candidates} 个候选记忆 / {written} 个新文件")
    print(f"Pending 目录: {PENDING_DIR}")

    # 写日志
    log_path = LOG_DIR / f"extract-candidates-{datetime.now().strftime('%Y-%m-%d')}.log"
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with open(log_path, "a") as f:
        f.write(
            f"[{datetime.now().isoformat()}] "
            f"files={len(recent)} candidates={total_candidates} written={written}\n"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
