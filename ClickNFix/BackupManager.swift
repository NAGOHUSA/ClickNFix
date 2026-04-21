import Foundation

enum BackupError: LocalizedError {
    case noUndoData
    case snapshotFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .noUndoData:
            return "No backup is available to restore"
        case .snapshotFailed(let code):
            return "Failed to create local snapshot (exit \(code))"
        }
    }
}

struct BackupRecord: Codable {
    let fixName: String
    let backupFolderPath: String
    let originalPaths: [String]
}

final class BackupManager {
    private let fm = FileManager.default
    private var backupRoot: URL {
        fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/OptimacOSGUI/Backups", isDirectory: true)
    }

    private var metadataURL: URL {
        backupRoot.appendingPathComponent("last_backup.json")
    }

    var hasUndoData: Bool {
        fm.fileExists(atPath: metadataURL.path)
    }

    @discardableResult
    func createBackup(for fix: FixType, paths: [String], dryRun: Bool) throws -> BackupRecord? {
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        guard !paths.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let folder = backupRoot.appendingPathComponent("\(fix.rawValue)-\(timestamp)", isDirectory: true)

        if !dryRun {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for path in paths {
                let expanded = (path as NSString).expandingTildeInPath
                guard fm.fileExists(atPath: expanded) else { continue }

                let target = folder.appendingPathComponent(safePath(expanded))
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: target)
                try fm.copyItem(atPath: expanded, toPath: target.path)
            }

            let record = BackupRecord(fixName: fix.rawValue, backupFolderPath: folder.path, originalPaths: paths)
            let data = try JSONEncoder().encode(record)
            try data.write(to: metadataURL)
            return record
        }

        return BackupRecord(fixName: fix.rawValue, backupFolderPath: folder.path, originalPaths: paths)
    }

    func undoLastFix(dryRun: Bool) throws {
        guard fm.fileExists(atPath: metadataURL.path) else {
            throw BackupError.noUndoData
        }

        let data = try Data(contentsOf: metadataURL)
        let record = try JSONDecoder().decode(BackupRecord.self, from: data)

        if !dryRun {
            for path in record.originalPaths {
                let expanded = (path as NSString).expandingTildeInPath
                let source = URL(fileURLWithPath: record.backupFolderPath)
                    .appendingPathComponent(safePath(expanded))
                guard fm.fileExists(atPath: source.path) else { continue }
                try? fm.removeItem(atPath: expanded)
                try fm.createDirectory(atPath: (expanded as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                try fm.copyItem(atPath: source.path, toPath: expanded)
            }
        }

        try? fm.removeItem(at: metadataURL)
    }

    func createLocalSnapshot(dryRun: Bool) throws {
        if dryRun { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["localsnapshot"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BackupError.snapshotFailed(process.terminationStatus)
        }
    }

    private func safePath(_ fullPath: String) -> String {
        fullPath
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
