import Foundation
import Combine

/// Owns the list of configured Claude accounts, the active selection, and a low-frequency
/// background poller that fills in compact `AccountPeek` snapshots for inactive accounts
/// so the popover switcher can render percentages alongside each entry.
///
/// Session keys live in Keychain under `session_key.<accountId>`. Demo accounts use a
/// hardcoded key and skip Keychain entirely.
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var activeId: String?
    @Published private(set) var peeks: [String: AccountPeek] = [:]

    /// In-memory cache of the last successful `ClawdUsageData` per account. Survives
    /// switches within a session so the popover can repaint stale data when the user
    /// flips back to an account whose key has expired. Reset on app relaunch.
    private(set) var snapshots: [String: ClawdUsageData] = [:]

    private let notificationManager: NotificationManager

    private static let accountsKey = "clawdephobia.accounts"
    private static let activeIdKey = "clawdephobia.active_account_id"
    private static let schemaKey = "clawdephobia.accounts_schema_v1"
    private static let legacySessionKeychainKey = "session_key"
    static let syncTerminalLoginKey = "clawdephobia.sync_terminal_login"

    /// Synthetic in-memory key for the demo account.
    static let demoSessionKey = "sk-ant-demo01-xK9pQr2vT8wLnY7cBZhJ5dF0uCmNqWsA3e6R1P4xK9pQr2vT8wLnY7-AA"

    private var inactiveTimer: Timer?
    private static let inactiveInterval: TimeInterval = 600          // 10 min background sweep
    private static let inactivePeekCooldown: TimeInterval = 30       // popover-open burst limit

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        loadFromDisk()
        startInactiveTimer()
        Task { await migrateIfNeeded() }
    }

    private static func keychainKey(for accountId: String) -> String {
        "session_key.\(accountId)"
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.accountsKey),
           let list = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = list
        }
        activeId = defaults.string(forKey: Self.activeIdKey)
        if activeId == nil || !accounts.contains(where: { $0.id == activeId }) {
            activeId = accounts.first?.id
            persistActiveId()
        }
    }

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.accountsKey)
        }
    }

    private func persistActiveId() {
        if let id = activeId {
            UserDefaults.standard.set(id, forKey: Self.activeIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activeIdKey)
        }
    }

    // MARK: - Lookups

    func account(for id: String) -> Account? {
        accounts.first(where: { $0.id == id })
    }

    var activeAccount: Account? {
        guard let id = activeId else { return nil }
        return account(for: id)
    }

    func sessionKey(for accountId: String) -> String? {
        if accountId == Account.demoId { return Self.demoSessionKey }
        return KeychainHelper.load(key: Self.keychainKey(for: accountId))
    }

    var activeSessionKey: String? {
        guard let id = activeId else { return nil }
        return sessionKey(for: id)
    }

    // MARK: - Mutations

    func setActive(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        guard id != activeId else { return }
        let previousId = activeId
        syncTerminalOnSwitch(from: previousId, to: id)
        activeId = id
        persistActiveId()
    }

    // MARK: - Terminal (Claude Code CLI) login sync

    /// True when the user has opted in to swapping the `claude` CLI login on account switch.
    var syncTerminalLoginEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.syncTerminalLoginKey)
    }

    /// True when this account has a captured CLI login snapshot to restore on switch.
    func terminalLoginLinked(for id: String) -> Bool {
        ClaudeCodeCredentialBridge.loadSnapshot(for: id) != nil
    }

    /// True when a `claude` process is currently running (its session won't pick up a swap).
    func isClaudeRunning() -> Bool {
        ClaudeCodeCredentialBridge.isClaudeRunning()
    }

    /// Captures the live `Claude Code-credentials` Keychain item and links it to `id`.
    /// Surfaces `ClaudeCodeCredentialBridge.BridgeError` (e.g. `.notLoggedIn`) on failure.
    func captureTerminalLogin(for id: String) throws {
        let blob = try ClaudeCodeCredentialBridge.captureLive()
        ClaudeCodeCredentialBridge.storeSnapshot(blob, for: id)
    }

    /// On switch: refresh the outgoing account's snapshot from the live item (only if it was
    /// already linked, so we never mislabel a login the app didn't capture), then restore the
    /// incoming account's snapshot to the live item. No-ops when the feature is off/unsupported
    /// or the incoming account has no snapshot (leaving the live login untouched).
    private func syncTerminalOnSwitch(from previousId: String?, to newId: String) {
        guard syncTerminalLoginEnabled, ClaudeCodeCredentialBridge.isSupported else { return }
        if let previousId, ClaudeCodeCredentialBridge.loadSnapshot(for: previousId) != nil,
           let live = try? ClaudeCodeCredentialBridge.captureLive() {
            ClaudeCodeCredentialBridge.storeSnapshot(live, for: previousId)
        }
        guard let blob = ClaudeCodeCredentialBridge.loadSnapshot(for: newId) else { return }
        try? ClaudeCodeCredentialBridge.writeLive(blob)
    }

    func rename(_ id: String, to newLabel: String) {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[idx].label = trimmed
        persistAccounts()
    }

    /// Validates the session key, fetches the org's UUID and name, then upserts the account.
    /// If an account with the same UUID already exists, its key is rotated and its
    /// detectedName refreshed (but the user-edited label is preserved).
    @discardableResult
    func add(sessionKey: String) async throws -> Account {
        let trimmed = sessionKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ClawdAPIError.invalidResponse("Empty session key")
        }
        let scraper = UsageScraper(sessionKey: trimmed)
        let info = try await scraper.fetchOrgInfo()
        return upsert(orgInfo: info, sessionKey: trimmed)
    }

    /// Adds a synthetic demo account (or activates the existing one). No network call.
    @discardableResult
    func addDemo() -> Account {
        if let existing = account(for: Account.demoId) {
            setActive(existing.id)
            return existing
        }
        let demo = Account(
            id: Account.demoId,
            label: "Demo",
            detectedName: "Demo",
            addedAt: Date()
        )
        accounts.append(demo)
        persistAccounts()
        setActive(demo.id)
        return demo
    }

    func remove(id: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts.remove(at: idx)
        peeks.removeValue(forKey: id)
        snapshots.removeValue(forKey: id)
        if id != Account.demoId {
            KeychainHelper.delete(key: Self.keychainKey(for: id))
        }
        ClaudeCodeCredentialBridge.deleteSnapshot(for: id)
        notificationManager.reset(accountId: id)
        persistAccounts()
        if activeId == id {
            activeId = accounts.first?.id
            persistActiveId()
        }
    }

    /// Stores the latest successful usage payload for `id`. Used by `UsageViewModel`
    /// (active account) and by `refreshPeek` (inactive sweep).
    func recordSnapshot(id: String, data: ClawdUsageData) {
        snapshots[id] = data
    }

    func snapshot(for id: String) -> ClawdUsageData? {
        snapshots[id]
    }

    /// Wipes every account and removes their Keychain keys. Used by Settings → Reset All Data.
    func removeAll() {
        for account in accounts where !account.isDemo {
            KeychainHelper.delete(key: Self.keychainKey(for: account.id))
            ClaudeCodeCredentialBridge.deleteSnapshot(for: account.id)
        }
        accounts.removeAll()
        peeks.removeAll()
        snapshots.removeAll()
        activeId = nil
        persistAccounts()
        persistActiveId()
        notificationManager.reset()
        UserDefaults.standard.removeObject(forKey: Self.schemaKey)
    }

    private func upsert(orgInfo: OrgInfo, sessionKey: String) -> Account {
        KeychainHelper.save(key: Self.keychainKey(for: orgInfo.uuid), value: sessionKey)
        if let idx = accounts.firstIndex(where: { $0.id == orgInfo.uuid }) {
            accounts[idx].detectedName = orgInfo.name
            persistAccounts()
            setActive(orgInfo.uuid)
            return accounts[idx]
        }
        let label = orgInfo.name?.trimmingCharacters(in: .whitespaces).nonEmpty ?? defaultLabel()
        let account = Account(
            id: orgInfo.uuid,
            label: label,
            detectedName: orgInfo.name,
            addedAt: Date()
        )
        accounts.append(account)
        persistAccounts()
        // Always switch to the freshly added account so the popover reflects it
        // immediately — users want to confirm the new key works.
        setActive(account.id)
        return account
    }

    private func defaultLabel() -> String {
        let n = accounts.filter { !$0.isDemo }.count + 1
        return "Account \(n)"
    }

    // MARK: - Migration from single-account era

    private func migrateIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.schemaKey) { return }
        if !accounts.isEmpty {
            defaults.set(true, forKey: Self.schemaKey)
            return
        }
        guard let legacy = KeychainHelper.load(key: Self.legacySessionKeychainKey) else {
            defaults.set(true, forKey: Self.schemaKey)
            return
        }
        // Demo legacy users: skip a network call.
        if legacy == Self.demoSessionKey {
            KeychainHelper.delete(key: Self.legacySessionKeychainKey)
            addDemo()
            defaults.set(true, forKey: Self.schemaKey)
            return
        }
        do {
            let scraper = UsageScraper(sessionKey: legacy)
            let info = try await scraper.fetchOrgInfo()
            KeychainHelper.save(key: Self.keychainKey(for: info.uuid), value: legacy)
            KeychainHelper.delete(key: Self.legacySessionKeychainKey)
            let acc = Account(
                id: info.uuid,
                label: info.name?.trimmingCharacters(in: .whitespaces).nonEmpty ?? "My account",
                detectedName: info.name,
                addedAt: Date()
            )
            accounts.append(acc)
            persistAccounts()
            setActive(acc.id)
            defaults.set(true, forKey: Self.schemaKey)
        } catch {
            // Migration deferred — retry on next launch so the user doesn't lose their key.
        }
    }

    // MARK: - Inactive polling

    private func startInactiveTimer() {
        inactiveTimer?.invalidate()
        inactiveTimer = Timer.scheduledTimer(withTimeInterval: Self.inactiveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshInactives() }
        }
    }

    /// Eager refresh for popover-open events. Skips accounts that were polled in the last 30s.
    func refreshInactivesIfStale() {
        Task { @MainActor in
            for acc in accounts where acc.id != activeId {
                if let last = peeks[acc.id]?.updatedAt,
                   Date().timeIntervalSince(last) < Self.inactivePeekCooldown {
                    continue
                }
                await refreshPeek(for: acc)
            }
        }
    }

    private func refreshInactives() {
        Task { @MainActor in
            for acc in accounts where acc.id != activeId {
                await refreshPeek(for: acc)
            }
        }
    }

    /// Fetches a peek snapshot for one account and fires any threshold notifications.
    /// Demo accounts return canned data without hitting the network.
    @discardableResult
    private func refreshPeek(for account: Account) async -> AccountPeek? {
        if account.isDemo {
            let peek = AccountPeek(
                sessionPercent: 0.72,
                weeklyPercent: 0.45,
                updatedAt: Date(),
                lastError: nil
            )
            peeks[account.id] = peek
            return peek
        }
        guard let key = sessionKey(for: account.id) else { return nil }
        let scraper = UsageScraper(sessionKey: key)
        do {
            let data = try await scraper.scrape()
            let peek = AccountPeek(
                sessionPercent: data.fiveHour?.percentUsed ?? 0,
                weeklyPercent: data.sevenDay?.percentUsed ?? 0,
                updatedAt: Date(),
                lastError: nil
            )
            peeks[account.id] = peek
            recordSnapshot(id: account.id, data: data)
            fireInactiveNotifications(account: account, data: data)
            return peek
        } catch {
            let existing = peeks[account.id]
            let peek = AccountPeek(
                sessionPercent: existing?.sessionPercent ?? 0,
                weeklyPercent: existing?.weeklyPercent ?? 0,
                updatedAt: Date(),
                lastError: error.localizedDescription
            )
            peeks[account.id] = peek
            return peek
        }
    }

    private func fireInactiveNotifications(account: Account, data: ClawdUsageData) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "clawdephobia.notifications_enabled") as? Bool ?? true
        guard enabled else { return }
        let warn = defaults.object(forKey: "clawdephobia.warning_threshold") as? Double ?? 0.75
        let crit = defaults.object(forKey: "clawdephobia.critical_threshold") as? Double ?? 0.90
        let notifyReset = defaults.object(forKey: "clawdephobia.notify_on_reset") as? Bool ?? true

        func notify(_ label: String, _ info: RateLimitInfo?) {
            guard let info = info else { return }
            notificationManager.checkAndNotify(
                accountId: account.id,
                accountLabel: account.label,
                label: label,
                percentUsed: info.percentUsed,
                warningThreshold: warn,
                criticalThreshold: crit,
                notifyOnReset: notifyReset
            )
        }
        notify("5-hour session", data.fiveHour)
        notify("7-day weekly", data.sevenDay)
        notify("Opus weekly", data.sevenDayOpus)
        notify("Sonnet weekly", data.sevenDaySonnet)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
