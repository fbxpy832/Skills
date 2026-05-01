# My AI Skills

我的自建通用 AI Skills 源仓库。

## 用途

本仓库存放我个人自建的通用 AI Skills，适用于 Claude Code、Codex、OpenCode、Hermes、OpenClaw 等 AI 工具。

通过 **CC Switch** 分发到各个工具的 Skill 目录。

## 仓库位置

```bash
~/Documents/RichardHub/Git/Skills
```

- 位于 iCloud 云盘同步范围内
- 同时也是 Git 仓库

## 安装到 CC Switch

CC Switch 不直接扫描本目录。

需要通过安装脚本复制到 CC Switch 工作目录：

```bash
# 安装脚本
./_scripts/install-to-ccswitch.sh
```

## 其他电脑同步并安装

```bash
./_scripts/update-and-install.sh
```

## 检查安装状态

```bash
./_scripts/check-install-status.sh
```

## 日常使用流程

### 本机修改 Skill 后

```bash
cd ~/Documents/RichardHub/Git/Skills
git add .
git commit -m "update skills"
git push
./_scripts/install-to-ccswitch.sh
```

然后打开 **CC Switch**，刷新 Skills，把需要的 Skill 用「文件复制」模式同步到目标工具。

### 其他电脑接入

```bash
cd ~/Documents/RichardHub/Git/Skills
./_scripts/update-and-install.sh
```

然后打开 CC Switch 刷新并同步。

## 新增 Skill 的标准方式

在仓库一级目录创建新文件夹，并添加 SKILL.md：

```
my-new-skill/
  SKILL.md
```

可参考 `_templates/SKILL_TEMPLATE.md` 创建。

## 安全规则

- 不要把密钥、token、账号、密码、.env、私钥文件提交到仓库
- 安装脚本会自动排除 `.env`、`secrets.*`、`*.key`、`*.pem` 等敏感文件

## 分发机制

本仓库通过安装脚本复制到 `~/.cc-switch/skills`，再由 CC Switch 分发到各 AI 工具。

**推荐 CC Switch 使用「文件复制」模式，而非软链接模式。**

不直接同步 `~/.claude`、`~/.codex`、`~/.hermes`、`~/.opencode`、`~/.openclaw`。
