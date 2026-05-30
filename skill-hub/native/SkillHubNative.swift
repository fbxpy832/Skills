import AppKit
import CryptoKit
import Foundation

struct Target {
    let id: String
    let name: String
    let path: String
}

struct Skill {
    let id: String
    let name: String
    let description: String
    let path: String
    let hash: String
    var statuses: [String: String]
}

let defaultSourceRoot = "/Users/xpy/Documents/RichardHub/Git"
let defaultTargets = [
    Target(id: "codex", name: "Codex", path: "\(NSHomeDirectory())/.codex/skills"),
    Target(id: "claude", name: "Claude Code", path: "\(NSHomeDirectory())/.claude/skills"),
    Target(id: "opencode", name: "OpenCode", path: "\(NSHomeDirectory())/.config/opencode/skills"),
    Target(id: "hermes", name: "Hermes Agent", path: "\(NSHomeDirectory())/.hermes/skills")
]

let excludedNames: Set<String> = [
    ".git", ".hg", ".svn", ".DS_Store", ".env", ".env.local", ".env.production",
    "node_modules", "__pycache__", ".venv", "venv", "dist", "build",
    ".codex-opencode", ".superpowers"
]

let excludedExtensions: Set<String> = [".pem", ".key", ".p12", ".pfx", ".crt", ".cer", ".sqlite", ".db"]

func isExcluded(_ name: String) -> Bool {
    let lower = name.lowercased()
    return excludedNames.contains(name)
        || excludedNames.contains(lower)
        || lower.contains("cookie")
        || lower.contains("secret")
        || lower.hasSuffix(".log")
        || excludedExtensions.contains(URL(fileURLWithPath: lower).pathExtension.isEmpty ? "" : ".\(URL(fileURLWithPath: lower).pathExtension)")
}

func fileExists(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: path)
}

func collectFiles(root: URL, current: URL) throws -> [(relative: String, absolute: URL)] {
    let entries = try FileManager.default.contentsOfDirectory(
        at: current,
        includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    var files: [(relative: String, absolute: URL)] = []

    for entry in entries {
        if isExcluded(entry.lastPathComponent) { continue }
        let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values.isDirectory == true {
            files += try collectFiles(root: root, current: entry)
        } else if values.isRegularFile == true {
            let relative = entry.path.replacingOccurrences(of: root.path + "/", with: "")
            files.append((relative.split(separator: "/").joined(separator: "/"), entry))
        }
    }

    return files
}

func hashDirectory(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: path)
    var hasher = SHA256()
    let files = try collectFiles(root: root, current: root).sorted { $0.relative < $1.relative }

    for file in files {
        hasher.update(data: Data(file.relative.utf8))
        hasher.update(data: Data([0]))
        hasher.update(data: try Data(contentsOf: file.absolute))
        hasher.update(data: Data([0]))
    }

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

func readMetadata(skillFile: String) -> (name: String?, description: String?) {
    guard let content = try? String(contentsOfFile: skillFile, encoding: .utf8), content.hasPrefix("---") else {
        return (nil, nil)
    }
    guard let range = content.range(of: "\n---", range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) else {
        return (nil, nil)
    }
    let frontmatter = content[content.index(content.startIndex, offsetBy: 3)..<range.lowerBound]
    var name: String?
    var description: String?

    for line in frontmatter.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { continue }
        let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if parts[0] == "name" { name = value }
        if parts[0] == "description" { description = value }
    }

    return (name, description)
}

func listSkills(sourceRoot: String) throws -> [Skill] {
    let root = URL(fileURLWithPath: sourceRoot)
    let entries = try FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )
    var skills: [Skill] = []

    for entry in entries {
        if isExcluded(entry.lastPathComponent) { continue }
        let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { continue }

        let skillFile = entry.appendingPathComponent("SKILL.md").path
        guard fileExists(skillFile) else { continue }
        let metadata = readMetadata(skillFile: skillFile)
        skills.append(Skill(
            id: entry.lastPathComponent,
            name: metadata.name ?? entry.lastPathComponent,
            description: metadata.description ?? "",
            path: entry.path,
            hash: try hashDirectory(entry.path),
            statuses: [:]
        ))
    }

    return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

func compare(skill: Skill, target: Target) -> String {
    let targetPath = URL(fileURLWithPath: target.path).appendingPathComponent(skill.id).path
    guard fileExists(targetPath) else { return "missing" }
    guard fileExists(URL(fileURLWithPath: targetPath).appendingPathComponent("SKILL.md").path) else { return "conflict" }
    guard let targetHash = try? hashDirectory(targetPath) else { return "conflict" }
    return targetHash == skill.hash ? "synced" : "outdated"
}

func copySkill(source: String, destination: String) throws {
    let fm = FileManager.default
    try fm.createDirectory(atPath: destination, withIntermediateDirectories: true)
    let entries = try fm.contentsOfDirectory(at: URL(fileURLWithPath: source), includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey])
    for entry in entries {
        if isExcluded(entry.lastPathComponent) { continue }
        let to = URL(fileURLWithPath: destination).appendingPathComponent(entry.lastPathComponent).path
        let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values.isDirectory == true {
            try copySkill(source: entry.path, destination: to)
        } else if values.isRegularFile == true {
            try fm.copyItem(atPath: entry.path, toPath: to)
        }
    }
}

func backupExistingTarget(_ targetSkillPath: String) throws -> String {
    guard fileExists(targetSkillPath) else { return "" }
    let url = URL(fileURLWithPath: targetSkillPath)
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let backupRoot = url.deletingLastPathComponent().appendingPathComponent(".skill-hub-backups")
    let backup = backupRoot.appendingPathComponent("\(url.lastPathComponent)-\(stamp)")
    try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: url, to: backup)
    return backup.path
}

final class SkillHubController: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    let sourceField = NSTextField(string: defaultSourceRoot)
    let tableView = NSTableView()
    let logView = NSTextView()
    let scanButton = NSButton(title: "Scan", target: nil, action: nil)
    let pullButton = NSButton(title: "Pull", target: nil, action: nil)
    let syncButton = NSButton(title: "Sync Selected", target: nil, action: nil)
    let deleteButton = NSButton(title: "Delete Selected", target: nil, action: nil)
    let forceCheck = NSButton(checkboxWithTitle: "Force", target: nil, action: nil)
    var targetChecks: [NSButton] = []
    var skills: [Skill] = []
    let targets = defaultTargets

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildUI()
        scan()
    }

    func buildUI() {
        window.title = "Skill Hub"
        window.center()
        window.contentView = NSView()
        guard let content = window.contentView else { return }

        let top = NSStackView()
        top.orientation = .horizontal
        top.spacing = 8
        top.translatesAutoresizingMaskIntoConstraints = false

        sourceField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scanButton.target = self
        scanButton.action = #selector(scan)
        pullButton.target = self
        pullButton.action = #selector(pullSource)
        syncButton.target = self
        syncButton.action = #selector(syncSelected)
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelected)

        top.addArrangedSubview(NSTextField(labelWithString: "Source"))
        top.addArrangedSubview(sourceField)
        top.addArrangedSubview(scanButton)
        top.addArrangedSubview(pullButton)
        top.addArrangedSubview(syncButton)
        top.addArrangedSubview(deleteButton)
        top.addArrangedSubview(forceCheck)

        let targetStack = NSStackView()
        targetStack.orientation = .horizontal
        targetStack.spacing = 10
        targetStack.translatesAutoresizingMaskIntoConstraints = false
        targetStack.addArrangedSubview(NSTextField(labelWithString: "Targets"))
        for target in targets {
            let check = NSButton(checkboxWithTitle: target.name, target: self, action: nil)
            check.state = .on
            targetChecks.append(check)
            targetStack.addArrangedSubview(check)
        }

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.documentView = tableView

        let skillColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("skill"))
        skillColumn.title = "Skill"
        skillColumn.width = 240
        tableView.addTableColumn(skillColumn)
        for target in targets {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(target.id))
            column.title = target.name
            column.width = 120
            tableView.addTableColumn(column)
        }
        tableView.allowsMultipleSelection = true
        tableView.dataSource = self
        tableView.delegate = self

        let logScroll = NSScrollView()
        logScroll.translatesAutoresizingMaskIntoConstraints = false
        logScroll.hasVerticalScroller = true
        logScroll.documentView = logView
        logView.isEditable = false
        logView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        content.addSubview(top)
        content.addSubview(targetStack)
        content.addSubview(scroll)
        content.addSubview(logScroll)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            top.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            top.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            sourceField.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),

            targetStack.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 8),
            targetStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            targetStack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),

            scroll.topAnchor.constraint(equalTo: targetStack.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: logScroll.topAnchor, constant: -10),

            logScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            logScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            logScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            logScroll.heightAnchor.constraint(equalToConstant: 120)
        ])

        window.makeKeyAndOrderFront(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        skills.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < skills.count, let identifier = tableColumn?.identifier.rawValue else { return nil }
        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingTail
        if identifier == "skill" {
            text.stringValue = skills[row].name
            text.toolTip = skills[row].description
        } else {
            text.stringValue = skills[row].statuses[identifier] ?? "-"
            text.alignment = .center
        }
        return text
    }

    func selectedTargets() -> [Target] {
        targets.enumerated().filter { targetChecks[$0.offset].state == .on }.map { $0.element }
    }

    func selectedSkills() -> [Skill] {
        tableView.selectedRowIndexes.compactMap { index in
            index >= 0 && index < skills.count ? skills[index] : nil
        }
    }

    @objc func scan() {
        do {
            var next = try listSkills(sourceRoot: sourceField.stringValue)
            for index in next.indices {
                for target in targets {
                    next[index].statuses[target.id] = compare(skill: next[index], target: target)
                }
            }
            skills = next
            tableView.reloadData()
            log("Scan complete: \(skills.count) skill(s) found.")
        } catch {
            log("Scan failed: \(error.localizedDescription)")
        }
    }

    @objc func pullSource() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["pull", "--ff-only"]
        process.currentDirectoryURL = URL(fileURLWithPath: sourceField.stringValue)
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            log(process.terminationStatus == 0 ? "Git pull: \(output.isEmpty ? "Already up to date." : output)" : "Git pull failed: \(output)")
            scan()
        } catch {
            log("Git pull failed: \(error.localizedDescription)")
        }
    }

    @objc func syncSelected() {
        let pickedSkills = selectedSkills()
        let pickedTargets = selectedTargets()
        guard !pickedSkills.isEmpty, !pickedTargets.isEmpty else {
            log("Select at least one skill and one target.")
            return
        }

        for skill in pickedSkills {
            for target in pickedTargets {
                let targetSkillPath = URL(fileURLWithPath: target.path).appendingPathComponent(skill.id).path
                let status = compare(skill: skill, target: target)
                if status == "conflict" && forceCheck.state != .on {
                    log("\(skill.id) -> \(target.id): skipped conflict")
                    continue
                }
                if status == "synced" {
                    log("\(skill.id) -> \(target.id): already up to date")
                    continue
                }
                do {
                    _ = try backupExistingTarget(targetSkillPath)
                    try FileManager.default.createDirectory(atPath: target.path, withIntermediateDirectories: true)
                    try? FileManager.default.removeItem(atPath: targetSkillPath)
                    try copySkill(source: skill.path, destination: targetSkillPath)
                    log("\(skill.id) -> \(target.id): synced")
                } catch {
                    log("\(skill.id) -> \(target.id): sync failed: \(error.localizedDescription)")
                }
            }
        }
        scan()
    }

    @objc func deleteSelected() {
        let pickedSkills = selectedSkills()
        let pickedTargets = selectedTargets()
        guard !pickedSkills.isEmpty, !pickedTargets.isEmpty else {
            log("Select at least one skill and one target.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete selected installed skills?"
        alert.informativeText = "This only removes selected skills from selected target directories. Source skill folders are not deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for skill in pickedSkills {
            for target in pickedTargets {
                let targetSkillPath = URL(fileURLWithPath: target.path).appendingPathComponent(skill.id).path
                let status = compare(skill: skill, target: target)
                if status == "missing" {
                    log("\(skill.id) -> \(target.id): already missing")
                    continue
                }
                if status == "conflict" {
                    log("\(skill.id) -> \(target.id): skipped conflict")
                    continue
                }
                do {
                    try FileManager.default.removeItem(atPath: targetSkillPath)
                    log("\(skill.id) -> \(target.id): deleted")
                } catch {
                    log("\(skill.id) -> \(target.id): delete failed: \(error.localizedDescription)")
                }
            }
        }
        scan()
    }

    func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        logView.textStorage?.append(NSAttributedString(string: line))
        logView.scrollToEndOfDocument(nil)
    }
}

let app = NSApplication.shared
let delegate = SkillHubController()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
