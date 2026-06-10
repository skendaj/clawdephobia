import Foundation
import Security

/// Reads and writes the Keychain item that Claude Code (the CLI) uses for its
/// OAuth tokens, and keeps per-account snapshots in Clawdephobia's own Keychain
/// namespace so the user can swap CLI logins when they switch the active
/// Clawdephobia account.
///
/// Live item: service `Claude Code-credentials`, account = current Unix user.
/// Snapshot per Clawdephobia account: `KeychainHelper` key `cc_credentials.<id>`,
/// stored under Clawdephobia's own service so the user's existing Keychain ACL
/// covers it.
enum ClaudeCodeCredentialBridge {
    static let liveService = "Claude Code-credentials"
    private static let snapshotKeyPrefix = "cc_credentials."

    /// Terminal sync requires reading/writing another app's Keychain item, which the
    /// macOS sandbox forbids. The Mac App Store build is sandboxed; the direct-download
    /// (DevID/DMG) and Debug builds are not. The sandbox exposes a container id in the
    /// environment, which we use as the runtime gate.
    static var isSupported: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
    }

    enum BridgeError: LocalizedError {
        case notLoggedIn
        case keychainWriteFailed(OSStatus)
        case keychainReadFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .notLoggedIn:
                return "Claude Code login not found. Run `claude login` in Terminal first, then click Capture."
            case .keychainWriteFailed(let status):
                return "Couldn't write Claude Code credentials (Keychain error \(status))."
            case .keychainReadFailed(let status):
                return "Couldn't read Claude Code credentials (Keychain error \(status))."
            }
        }
    }

    /// Reads the live `Claude Code-credentials` Keychain item for the current user
    /// and returns the raw blob. Throws `.notLoggedIn` when absent.
    static func captureLive() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: liveService,
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            throw BridgeError.notLoggedIn
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw BridgeError.keychainReadFailed(status)
        }
        return data
    }

    /// Replaces (or creates) the live `Claude Code-credentials` Keychain item with `blob`.
    /// Delete-then-add to avoid duplicates (mirrors `KeychainHelper.save`).
    static func writeLive(_ blob: Data) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: liveService,
            kSecAttrAccount as String: NSUserName(),
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = blob
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BridgeError.keychainWriteFailed(status)
        }
    }

    /// True when a `claude` process is running. Used to warn the user that
    /// rewriting the Keychain won't affect already-running sessions.
    static func isClaudeRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "claude"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Snapshot storage (per Clawdephobia account)

    private static func snapshotKey(for accountId: String) -> String {
        snapshotKeyPrefix + accountId
    }

    static func storeSnapshot(_ blob: Data, for accountId: String) {
        let encoded = blob.base64EncodedString()
        KeychainHelper.save(key: snapshotKey(for: accountId), value: encoded)
    }

    static func loadSnapshot(for accountId: String) -> Data? {
        guard let encoded = KeychainHelper.load(key: snapshotKey(for: accountId)) else {
            return nil
        }
        return Data(base64Encoded: encoded)
    }

    static func deleteSnapshot(for accountId: String) {
        KeychainHelper.delete(key: snapshotKey(for: accountId))
    }
}
