import Foundation
import Security

enum PermissionError: LocalizedError {
    case authorizationFailed(OSStatus)
    case executionFailed(OSStatus)
    case missingPipe

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let status):
            return "Authorization failed (\(status))"
        case .executionFailed(let status):
            return "Privileged execution failed (\(status))"
        case .missingPipe:
            return "Could not read privileged process output"
        }
    }
}

final class PermissionManager {
    private var authorizationRef: AuthorizationRef?

    deinit {
        if let authorizationRef {
            AuthorizationFree(authorizationRef, [])
        }
    }

    func requestAdminRights() throws {
        if authorizationRef == nil {
            let status = AuthorizationCreate(nil, nil, [], &authorizationRef)
            guard status == errAuthorizationSuccess else {
                throw PermissionError.authorizationFailed(status)
            }
        }

        var rightItem = AuthorizationItem(name: kAuthorizationRightExecute, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &rightItem)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        guard let ref = authorizationRef else {
            throw PermissionError.authorizationFailed(errAuthorizationInvalidRef)
        }
        let status = AuthorizationCopyRights(ref, &rights, nil, flags, nil)
        guard status == errAuthorizationSuccess else {
            throw PermissionError.authorizationFailed(status)
        }
    }

    func executePrivilegedTool(path: String, arguments: [String], output: @escaping (String) -> Void) async throws {
        try requestAdminRights()

        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var cArgs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
                cArgs.append(nil)
                defer { cArgs.forEach { free($0) } }

                var pipe: UnsafeMutablePointer<FILE>?
                guard let ref = self.authorizationRef else {
                    continuation.resume(throwing: PermissionError.authorizationFailed(errAuthorizationInvalidRef))
                    return
                }
                let status = path.withCString { toolPath in
                    AuthorizationExecuteWithPrivileges(
                        ref,
                        toolPath,
                        [],
                        &cArgs,
                        &pipe
                    )
                }

                guard status == errAuthorizationSuccess else {
                    continuation.resume(throwing: PermissionError.executionFailed(status))
                    return
                }

                guard let pipe else {
                    continuation.resume(throwing: PermissionError.missingPipe)
                    return
                }

                var lineBuffer = [CChar](repeating: 0, count: 4096)
                while fgets(&lineBuffer, Int32(lineBuffer.count), pipe) != nil {
                    let bytes = lineBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                    output(String(decoding: bytes, as: UTF8.self))
                }

                let closeStatus = fclose(pipe)
                if closeStatus == 0 {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PermissionError.executionFailed(OSStatus(closeStatus)))
                }
            }
        }
    }
}
