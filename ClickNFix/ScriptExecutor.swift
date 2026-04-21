import Foundation

enum ScriptExecutorError: LocalizedError {
    case scriptNotFound(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let script):
            return "Missing embedded script: \(script)"
        }
    }
}

final class ScriptExecutor {
    private let permissionManager = PermissionManager()

    func execute(fix: FixType, dryRun: Bool, output: @escaping (String) -> Void) async throws {
        let scriptURL =
            Bundle.main.url(forResource: fix.scriptName, withExtension: "sh", subdirectory: "OptimacOS") ??
            Bundle.main.url(forResource: fix.scriptName, withExtension: "sh")
        guard let scriptURL else {
            throw ScriptExecutorError.scriptNotFound(fix.scriptName)
        }

        let tempScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(fix.scriptName).sh")
        try FileManager.default.copyItem(at: scriptURL, to: tempScriptURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
        defer { try? FileManager.default.removeItem(at: tempScriptURL) }

        let args = dryRun ? [tempScriptURL.path, "--dry-run"] : [tempScriptURL.path]
        output("\u{001B}[34mRunning \(fix.displayName)...\u{001B}[0m\n")
        try await permissionManager.executePrivilegedTool(path: "/bin/bash", arguments: args, output: output)
        output("\u{001B}[32m\(fix.displayName) finished\u{001B}[0m\n")
    }
}
