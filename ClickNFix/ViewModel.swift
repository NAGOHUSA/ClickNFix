import AppKit
import Foundation
import SwiftUI

enum IssueSeverity {
    case none
    case warning
    case critical
}

enum FixExecutionStatus: Equatable {
    case idle
    case applicable
    case running
    case success
    case failure(String)

    var description: String {
        switch self {
        case .idle: return "Not scanned"
        case .applicable: return "Applicable"
        case .running: return "Running"
        case .success: return "Completed"
        case .failure(let error): return "Failed: \(error)"
        }
    }
}

enum FixCategory: String, CaseIterable {
    case system = "System"
    case storage = "Storage & Caches"
    case network = "Network"
    case cloud = "Cloud"

    var sfSymbol: String {
        switch self {
        case .system: return "cpu"
        case .storage: return "externaldrive"
        case .network: return "network"
        case .cloud: return "icloud"
        }
    }
}

enum FixType: String, CaseIterable, Identifiable {
    case finder
    case caches
    case permissions
    case launchServices
    case appCrashes
    case dns
    case icloud

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .finder: return "Fix Finder"
        case .caches: return "Clear Caches"
        case .permissions: return "Repair Permissions"
        case .launchServices: return "Reset Launch Services"
        case .appCrashes: return "Fix App Crashes"
        case .dns: return "Clear DNS Cache"
        case .icloud: return "Fix iCloud Sync"
        }
    }

    var fixDescription: String {
        switch self {
        case .finder:
            return "Resets Finder preferences and relaunches Finder to resolve UI glitches and stuck windows."
        case .caches:
            return "Removes user app caches to recover disk space and fix stale-data issues."
        case .permissions:
            return "Restores correct ownership and permissions on your home directory files."
        case .launchServices:
            return "Rebuilds the Launch Services database to fix \"Open With\" menus and default app associations."
        case .appCrashes:
            return "Clears crash-related caches and restarts the preference daemon to reduce repeated app crashes."
        case .dns:
            return "Flushes the DNS resolver cache and restarts mDNSResponder to fix slow or broken name lookups."
        case .icloud:
            return "Restarts iCloud sync agents to resolve stuck uploads, downloads, or missing files."
        }
    }

    var sfSymbol: String {
        switch self {
        case .finder: return "folder"
        case .caches: return "trash"
        case .permissions: return "lock.shield"
        case .launchServices: return "arrow.clockwise"
        case .appCrashes: return "exclamationmark.triangle"
        case .dns: return "network"
        case .icloud: return "icloud"
        }
    }

    var accentColor: String {
        switch self {
        case .finder: return "finderBlue"
        case .caches: return "cachesOrange"
        case .permissions: return "permGreen"
        case .launchServices: return "lsIndigo"
        case .appCrashes: return "crashRed"
        case .dns: return "dnsTeal"
        case .icloud: return "icloudBlue"
        }
    }

    var category: FixCategory {
        switch self {
        case .finder: return .system
        case .caches: return .storage
        case .permissions: return .system
        case .launchServices: return .storage
        case .appCrashes: return .system
        case .dns: return .network
        case .icloud: return .cloud
        }
    }

    var scriptName: String {
        switch self {
        case .finder: return "fix_finder"
        case .caches: return "clear_caches"
        case .permissions: return "repair_permissions"
        case .launchServices: return "reset_launch_services"
        case .appCrashes: return "fix_app_crashes"
        case .dns: return "clear_dns_cache"
        case .icloud: return "fix_icloud_sync"
        }
    }

    var requiresConfirmation: Bool {
        self == .caches || self == .permissions
    }

    var estimatedSeconds: Double {
        switch self {
        case .finder: return 10
        case .caches: return 60
        case .permissions: return 90
        case .launchServices: return 45
        case .appCrashes: return 30
        case .dns: return 10
        case .icloud: return 30
        }
    }

    var backupPaths: [String] {
        switch self {
        case .finder:
            return ["~/Library/Preferences/com.apple.finder.plist"]
        case .caches:
            return ["~/Library/Caches"]
        case .permissions:
            return ["~/Library/Preferences"]
        case .launchServices:
            return ["~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"]
        case .appCrashes:
            return ["~/Library/Logs/DiagnosticReports"]
        case .dns:
            return []
        case .icloud:
            return ["~/Library/Application Support/CloudDocs"]
        }
    }

    static func fixes(for category: FixCategory) -> [FixType] {
        allCases.filter { $0.category == category }
    }
}

@MainActor
final class ClickNFixViewModel: ObservableObject {
    private static let logRetentionDays = 30
    private static let progressIncrementWhenStartMissing = 0.05
    @Published private(set) var fixStatuses: [FixType: FixExecutionStatus] = [:]
    @Published var selectedFixes = Set(FixType.allCases)
    @Published var terminalOutput = AttributedString("")
    @Published var progress: Double = 0
    @Published var progressText = "Idle"
    @Published var dryRunMode = false
    @Published var createSnapshotBeforeBatch = true
    @Published var canUndo = false
    @Published var lastMessage: String?
    @Published private(set) var issueSeverity: IssueSeverity = .none {
        didSet {
            NotificationCenter.default.post(name: .issueSeverityDidChange, object: nil)
        }
    }

    private let scriptExecutor = ScriptExecutor()
    private let backupManager = BackupManager()
    private var logFileURL: URL?
    private var currentFixStartedAt: Date?

    init() {
        FixType.allCases.forEach { fixStatuses[$0] = .idle }
        rotateLogs()
    }

    func status(for fix: FixType) -> FixExecutionStatus {
        fixStatuses[fix] ?? .idle
    }

    func scanSystem() {
        var warnings = 0
        var critical = 0
        for fix in FixType.allCases {
            let applicable = isApplicable(fix)
            fixStatuses[fix] = applicable ? .applicable : .idle
            if applicable {
                if fix == .permissions || fix == .icloud { critical += 1 } else { warnings += 1 }
            }
        }

        issueSeverity = critical > 0 ? .critical : (warnings > 0 ? .warning : .none)
        appendLog("\u{001B}[36mScan complete. Warnings: \(warnings), Critical: \(critical)\u{001B}[0m\n")
        lastMessage = "Scan complete"
    }

    func run(fix: FixType) {
        Task {
            await executeFix(fix)
        }
    }

    func runAllSelectedFixes() {
        Task {
            if createSnapshotBeforeBatch {
                do {
                    try backupManager.createLocalSnapshot(dryRun: dryRunMode)
                    appendLog("\u{001B}[34mCreated local snapshot\u{001B}[0m\n")
                } catch {
                    appendLog("\u{001B}[31mSnapshot failed: \(error.localizedDescription)\u{001B}[0m\n")
                }
            }

            for fix in FixType.allCases where selectedFixes.contains(fix) {
                await executeFix(fix)
            }
        }
    }

    func undoLastFix() {
        Task {
            do {
                try backupManager.undoLastFix(dryRun: dryRunMode)
                appendLog("\u{001B}[32mUndo completed\u{001B}[0m\n")
                lastMessage = "Undo completed"
                canUndo = backupManager.hasUndoData
            } catch {
                appendLog("\u{001B}[31mUndo failed: \(error.localizedDescription)\u{001B}[0m\n")
                lastMessage = "Undo failed"
            }
        }
    }

    func viewLastLog() {
        guard let logFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }

    private func executeFix(_ fix: FixType) async {
        fixStatuses[fix] = .running
        progress = 0
        progressText = "\(fix.displayName)…"
        currentFixStartedAt = Date()

        do {
            _ = try backupManager.createBackup(for: fix, paths: fix.backupPaths, dryRun: dryRunMode)
            canUndo = backupManager.hasUndoData

            try await scriptExecutor.execute(
                fix: fix,
                dryRun: dryRunMode,
                output: { [weak self] line in
                    Task { @MainActor in
                        self?.appendLog(line)
                        self?.updateProgress(from: line, fallbackDuration: fix.estimatedSeconds)
                    }
                }
            )

            fixStatuses[fix] = .success
            progress = 1
            progressText = "Done"
            lastMessage = "\(fix.displayName) completed"
        } catch {
            fixStatuses[fix] = .failure(error.localizedDescription)
            progressText = "Failed"
            lastMessage = "\(fix.displayName) failed"
            appendLog("\u{001B}[31m\(fix.displayName) failed: \(error.localizedDescription)\u{001B}[0m\n")
        }
    }

    private func isApplicable(_ fix: FixType) -> Bool {
        let fm = FileManager.default
        switch fix {
        case .finder:
            return fm.fileExists(atPath: ("~/Library/Preferences/com.apple.finder.plist" as NSString).expandingTildeInPath)
        case .caches:
            return true
        case .permissions:
            return true
        case .launchServices:
            return fm.fileExists(atPath: ("~/Library/Preferences/com.apple.LaunchServices" as NSString).expandingTildeInPath)
        case .appCrashes:
            return fm.fileExists(atPath: ("~/Library/Logs/DiagnosticReports" as NSString).expandingTildeInPath)
        case .dns:
            return true
        case .icloud:
            return fm.fileExists(atPath: ("~/Library/Application Support/CloudDocs" as NSString).expandingTildeInPath)
        }
    }

    private func updateProgress(from line: String, fallbackDuration: Double) {
        if let value = Self.extractPercentage(line) {
            progress = min(max(value / 100, 0), 1)
            progressText = "\(Int(value))%"
            return
        }

        if line.lowercased().contains("done") || line.lowercased().contains("completed") {
            progress = 1
            progressText = "Done"
            return
        }

        guard let start = currentFixStartedAt else {
            progress = min(progress + Self.progressIncrementWhenStartMissing, 0.95)
            progressText = "Working…"
            return
        }

        let elapsed = Date().timeIntervalSince(start)
        let normalized = max(fallbackDuration, 1)
        progress = min(elapsed / normalized, 0.95)
        progressText = "~\(Int(max(normalized - elapsed, 0)))s left"
    }

    private static func extractPercentage(_ line: String) -> Double? {
        let pattern = #"(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line),
              let value = Double(line[valueRange]) else {
            return nil
        }
        return value
    }

    private func appendLog(_ text: String) {
        let attributed = ANSIParser.parse(text)
        terminalOutput += attributed
        if let logFileURL {
            do {
                try Data(text.utf8).append(to: logFileURL)
            } catch {
                lastMessage = "Log write failed: \(error.localizedDescription)"
            }
        }
    }

    private func rotateLogs() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/OptimacOSGUI", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let newLogFileURL = logsDir.appendingPathComponent("run-\(formatter.string(from: Date())).log")
        logFileURL = newLogFileURL
        FileManager.default.createFile(atPath: newLogFileURL.path, contents: nil)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.logRetentionDays, to: Date()) ?? Date.distantPast
        for file in files {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modified = values.contentModificationDate,
               modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

private enum ANSIParser {
    static func parse(_ input: String) -> AttributedString {
        var output = AttributedString("")
        var currentColor: Color = .primary

        let tokens = input.components(separatedBy: "\u{001B}[")
        if let first = tokens.first {
            var attr = AttributedString(first)
            attr.foregroundColor = currentColor
            output += attr
        }

        for token in tokens.dropFirst() {
            let parts = token.split(separator: "m", maxSplits: 1, omittingEmptySubsequences: false)
            guard let codePart = parts.first else { continue }
            let code = String(codePart)
            currentColor = color(for: code) ?? currentColor
            if parts.count > 1 {
                var attr = AttributedString(String(parts[1]))
                attr.foregroundColor = currentColor
                output += attr
            }
        }

        return output
    }

    private static func color(for ansiCode: String) -> Color? {
        switch ansiCode {
        case "0": return .primary
        case "31": return .red
        case "32": return .green
        case "33": return .yellow
        case "34": return .blue
        case "35": return .purple
        case "36": return .cyan
        default: return nil
        }
    }
}

final class AppServices {
    static let shared = AppServices()
    var viewModel = ClickNFixViewModel()
    private init() {}
}

private extension Data {
    func append(to url: URL) throws {
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: self)
        } else {
            try write(to: url)
        }
    }
}
