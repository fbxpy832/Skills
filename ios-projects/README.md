# iOS 开发工作区

> iCloud 云同步 · Git 版本控制 · 多 Mac 协作

## 架构概览

```
你的 Mac (主力机)                    Mac mini (家里)
     │                                     │
     │  编写代码 → git commit               │
     │         ↓                            │
     │   iCloud Drive 自动同步 ─────────→   │  iCloud 自动下载
     │                                     │  git log 查看更新
     │                                     │  Xcode 打开即可开发
     │                                     │
     │  ←───────── iCloud 自动同步 ──────── │  代码修改后 git commit
     │  iCloud 自动下载                     │
     │  git merge / rebase                  │
```

## 项目列表

| 项目 | 说明 | 技术栈 |
|------|------|--------|
| [SwiftUtils](./SwiftUtils) | 备忘录 + 计时器工具盒 | SwiftUI · MVVM · iOS 17+ |

## 快速开始（当前 Mac）

```bash
# 初始化 Git 仓库
cd SwiftUtils && sh setup-git.sh

# 用 Xcode 打开
open SwiftUtils.xcodeproj
```

## Mac mini 端初始化

在 Mac mini 上打开终端，运行：

```bash
# 确保已登录同一 Apple ID 并开启 iCloud Drive
sh ~/Documents/RichardHub/Git/ios-projects/macmini-setup.sh
```

首次可能需要等待 iCloud 同步完成（几分钟到几十分钟，取决于文件大小和网络）。

## 日常开发流程

### 在家用 Mac mini 开发

```bash
cd ~/Documents/RichardHub/Git/ios-projects/SwiftUtils
open SwiftUtils.xcodeproj    # 开始开发
git add -A && git commit -m "描述你的修改"
# iCloud 自动同步回主力机
```

### 回到主力机继续

```bash
cd ~/Documents/RichardHub/Git/ios-projects/SwiftUtils
open SwiftUtils.xcodeproj
# 查看 Mac mini 的提交：git log
# 文件已通过 iCloud 自动同步，直接继续开发即可
```

### 冲突避免

```bash
# 切换机器前，确保上次修改已提交
git status                    # 确认没有未提交的修改
git commit -am "保存当前进度"   # 提交所有修改

# 到另一台机器后，检查同步状态
git status
git log --oneline -5          # 查看最近的提交
```

## 注意事项

1. **iCloud 同步延迟**：文件修改后可能需要几秒到几分钟才会同步到另一台设备，修改前先检查是否最新
2. **不要在两台机器同时修改同一文件**：iCloud 会生成冲突副本（文件名带 "conflict"）
3. **大文件警告**：`DerivedData/`、`Pods/` 已在 .gitignore 中排除，但 Xcode 会在项目目录外生成这些，不占用 iCloud 空间
4. **Xcode 版本一致**：建议两台 Mac 使用相同版本的 Xcode，避免 project.pbxproj 格式冲突

## Git 分支策略建议

```bash
main          ← 稳定版本，随时可在两台 Mac 间同步
  ├── feat/xxx  ← 功能开发分支
  └── fix/xxx   ← 修复分支
```

在一台 Mac 上开发新功能时，建议开新分支，完成后合并到 main，另一台 Mac 拉取即可。</think>

<｜DSML｜tool_calls>
<｜DSML｜invoke name="Write">
<｜DSML｜parameter name="content" string="true"># iOS Dev Workspace

> iCloud 云同步 · Git 版本控制 · 多 Mac 协作

## 架构

```
主力 Mac                               Mac mini (家里)
   │                                       │
   │  写代码 → git commit                   │
   │      ↓                                  │
   │  iCloud 自动同步 ────────────────→     │  iCloud 自动下载
   │                                       │  打开 Xcode 直接开发
   │                                       │  git commit 提交修改
   │                                       │
   │  ←───────────────────────────────     │
   │  iCloud 自动下载                       │
```

项目文件通过 iCloud 在两台 Mac 之间自动同步，Git 负责版本管理。

## 项目

| 项目 | 说明 | 技术栈 |
|------|------|--------|
| [SwiftUtils](./SwiftUtils) | 备忘录 + 计时器 | SwiftUI · MVVM · iOS 17+ |

## 快速开始

### 当前 Mac（初始化 Git）

```bash
cd SwiftUtils
sh setup-git.sh
open SwiftUtils.xcodeproj
```

### Mac mini（首次同步）

```bash
sh ~/Documents/RichardHub/Git/ios-projects/macmini-setup.sh
```

## 日常流程

**切换机器前：**
```bash
git status      # 确认无未提交修改
git commit -am "保存进度"
```

**到另一台机器后：**
```bash
git log --oneline -5    # 查看最新提交
open SwiftUtils.xcodeproj  # 直接开发
```

## ⚠️ 注意事项

1. 不要在两台机器同时修改同一文件，否则 iCloud 会生成冲突副本
2. Xcode 编译产物（DerivedData）在项目外，不占 iCloud 空间
3. 建议两台 Mac 保持 Xcode 版本一致
4. iCloud 同步有几秒到几分钟的延迟