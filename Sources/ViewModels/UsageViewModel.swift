import Foundation
import Combine
import AppKit
import Network
import ServiceManagement

enum ShareAction: Int {
    case shareImage = 0
    case copyImage = 1
    case saveImage = 2
    case exportJSON = 3
}

final class UsageViewModel: ObservableObject {

    // MARK: - Published State

    @Published var sessionPercent: Double = 0
    @Published var sessionResetDescription: String = ""
    @Published var weeklyPercent: Double = 0
    @Published var weeklyResetDescription: String = ""

    // Model-specific weekly limits (shown when non-nil)
    @Published var opusPercent: Double?
    @Published var opusResetDescription: String?
    @Published var sonnetPercent: Double?
    @Published var sonnetResetDescription: String?

    // OAuth Apps weekly
    @Published var oauthAppsPercent: Double?
    @Published var oauthAppsResetDescription: String?

    // Cowork weekly
    @Published var coworkPercent: Double?
    @Published var coworkResetDescription: String?

    // Extra usage
    @Published var extraUsagePercent: Double?
    @Published var extraUsageResetDescription: String?

    /// Pay-as-you-go credit accounting (enterprise-style billing). Credit values
    /// are stored as raw API cents (`1437.0` = `$14.37`); convert at the view layer.
    @Published var extraCreditsEnabled: Bool = false
    @Published var extraCreditsUsed: Double?
    @Published var extraCreditsMonthlyLimit: Double?
    @Published var extraCreditsCurrency: String?
    /// "Resets MMM d" for the credit row — derived locally (API does not return it).
    @Published var creditsResetDescription: String = ""

    /// True only for true enterprise / credits-only plans. Either the API
    /// reports no 5-hour or 7-day window AND extra_usage credit billing is
    /// active, OR the resolved plan tier explicitly says Enterprise/Team. Pro
    /// accounts with extra_usage enabled stay non-enterprise so the regular
    /// 5h/7d bars keep rendering alongside a dedicated "Extra usage" section.
    var isEnterprise: Bool {
        if let name = planDisplayName, name == "Enterprise" || name == "Team" {
            return true
        }
        return extraCreditsEnabled && !hasSessionLimit && !hasWeeklyLimit
    }

    /// Prepaid credit balance (cents). `nil` when the endpoint is unavailable.
    @Published var prepaidBalanceCents: Double?
    @Published var prepaidCurrency: String?

    /// Authoritative monthly spend-limit. Cents per Anthropic convention.
    @Published var spendLimitEnabled: Bool = false
    @Published var spendLimitMonthlyCents: Double?
    @Published var spendLimitUsedCents: Double?
    @Published var spendLimitCurrency: String?
    @Published var spendLimitDisabledReason: String?
    @Published var spendLimitOutOfCredits: Bool = false

    /// Human-readable plan tier (e.g. "Pro", "Max 5×", "Enterprise"). Derived
    /// from `rateLimitTier`.
    @Published var planDisplayName: String?

    /// Set to true when the API actually reported a 5-hour / 7-day window for the
    /// active account. Enterprise plans return null for these; the popover hides
    /// the rows entirely when the corresponding flag is false.
    @Published var hasSessionLimit: Bool = false
    @Published var hasWeeklyLimit: Bool = false

    // Claude Design / Omelette
    @Published var omelettePercent: Double?
    @Published var omeletteResetDescription: String?

    /// Promotional Claude Design quota (separate counter on some plans).
    @Published var promotionalOmelettePercent: Double?
    @Published var promotionalOmeletteResetDescription: String?

    // Tier
    @Published var rateLimitTier: String?

    /// 0 = bars only, 1 = bars + text, 2 = bars + compact text
    @Published var menuBarDisplayMode: Int = 0
    /// 0 = bars, 1 = circles (menu bar icon)
    @Published var menuBarProgressStyle: Int = 0
    /// 0 = bars, 1 = circles (popover content view)
    @Published var viewProgressStyle: Int = 0

    @Published var isSetupComplete: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var showSettingsWindow: Bool = false
    @Published var pendingShareAction: ShareAction? = nil
    @Published var closePopoverRequested: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    /// True when using Clawd faster than sustainable for the current window
    @Published var isPacingWarning: Bool = false

    /// True when Clawd's service appears to be down (consecutive server/network failures)
    @Published var isServiceDown: Bool = false

    /// True when the active account's last fetch returned 401/403. Drives the
    /// "Session expired — update your key" banner in the popover.
    @Published var isUnauthorized: Bool = false

    /// Non-nil when a newer GitHub release is available and not yet dismissed
    @Published var updateAvailableVersion: String? = nil
    @Published var updateReleaseURL: String = ""

    /// Refresh interval in seconds (60, 300, 600)
    @Published var refreshInterval: Int = 300

    /// Warning threshold (0.0–1.0)
    @Published var warningThreshold: Double = 0.75
    /// Critical threshold (0.0–1.0)
    @Published var criticalThreshold: Double = 0.90

    /// Notify when limits reset
    @Published var notifyOnReset: Bool = true

    /// Phone push notifications via ntfy.sh
    @Published var pushNotificationsEnabled: Bool = false
    @Published var pushTopic: String = ""
    @Published var pushServerURL: String = "https://ntfy.sh"

    /// Launch at login via SMAppService
    @Published var launchAtLogin: Bool = false

    /// Account failover behaviour when the active account is nearly out of usage.
    /// 0 = off, 1 = manual (notify only, default), 2 = ask to confirm, 3 = automatic.
    @Published var failoverMode: Int = 1

    /// Set in `confirm` mode when a jump is suggested — drives the popover prompt.
    @Published var pendingFailover: PendingFailover? = nil

    struct PendingFailover: Equatable {
        let fromLabel: String
        let toId: String
        let toLabel: String
        let fromPercent: Int
    }

    /// Either limit at/above this fraction marks the active account "almost out".
    private let failoverTriggerThreshold: Double = 0.95
    /// Account we've already acted on this over-threshold episode, to avoid re-alerting
    /// every refresh. Cleared when the active account changes or drops back below.
    private var failoverAlertedAccountId: String?

    // MARK: - Services

    let accountStore: AccountStore
    private var scraper: UsageScraper?
    private var apiClient: ClawdAPIClient?
    private let notificationManager: NotificationManager
    private let updateChecker = UpdateChecker()
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private var networkMonitor: NWPathMonitor?
    private var wasNetworkUnsatisfied = false
    private var cancellables = Set<AnyCancellable>()

    /// Raw reset dates for live countdown
    private var sessionResetsAt: Date?
    private var weeklyResetsAt: Date?
    private var opusResetsAt: Date?
    private var sonnetResetsAt: Date?
    private var oauthAppsResetsAt: Date?
    private var coworkResetsAt: Date?
    private var extraUsageResetsAt: Date?
    private var omeletteResetsAt: Date?
    private var promotionalOmeletteResetsAt: Date?

    /// Minimum seconds between fetches (prevents hammering on popover open)
    private let minFetchInterval: TimeInterval = 30

    /// Consecutive server/network failure count for service-down detection
    private var consecutiveFailures = 0
    private let serviceDownThreshold = 3

    /// Stores the last fetched raw data for JSON export
    private var lastUsageData: ClawdUsageData?

    // MARK: - Init

    /// Data schema version — bump this to force a reset on next launch
    private static let dataSchemaVersion = 2

    init(accountStore: AccountStore, notificationManager: NotificationManager) {
        self.accountStore = accountStore
        self.notificationManager = notificationManager
        migrateAll()
        resetIfNewVersion()
        loadSettings()
        notificationManager.requestPermission()
        bindAccountStore()
        attachActiveAccount()
        startCountdownTimer()
        observeSystemEvents()
        Task { await checkForUpdate() }
    }

    private func bindAccountStore() {
        accountStore.$activeId
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.attachActiveAccount()
            }
            .store(in: &cancellables)

        accountStore.$accounts
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAny in
                self?.isSetupComplete = hasAny
                UserDefaults.standard.set(hasAny, forKey: "clawdephobia.setup_complete")
                if !hasAny { self?.clearActiveState() }
            }
            .store(in: &cancellables)
    }

    /// Called when the active account changes or on launch — rebuilds the scraper and
    /// kicks off a refresh against the newly active account.
    private func attachActiveAccount() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        failoverAlertedAccountId = nil
        pendingFailover = nil
        clearActiveState()
        guard let id = accountStore.activeId,
              let key = accountStore.activeSessionKey else { return }
        scraper = UsageScraper(sessionKey: key)
        apiClient = ClawdAPIClient(sessionKey: key)
        // Hydrate from in-memory snapshot so switching back to a previously-fetched
        // account doesn't flash empty bars before the network round-trip completes.
        if let snapshot = accountStore.snapshot(for: id) {
            lastUsageData = snapshot
            applyUsageData(snapshot)
            lastUpdated = Date()
        }
        startAutoRefresh()
        fetchUsage()
    }

    /// Zeros out the active-account-derived published state. Called when switching accounts
    /// (so the previous account's bars don't briefly show under the new label) and when all
    /// accounts are removed.
    private func clearActiveState() {
        scraper = nil
        apiClient = nil
        sessionPercent = 0
        weeklyPercent = 0
        opusPercent = nil
        opusResetDescription = nil
        sonnetPercent = nil
        sonnetResetDescription = nil
        oauthAppsPercent = nil
        oauthAppsResetDescription = nil
        coworkPercent = nil
        coworkResetDescription = nil
        extraUsagePercent = nil
        extraUsageResetDescription = nil
        extraCreditsEnabled = false
        extraCreditsUsed = nil
        extraCreditsMonthlyLimit = nil
        extraCreditsCurrency = nil
        creditsResetDescription = ""
        prepaidBalanceCents = nil
        prepaidCurrency = nil
        spendLimitEnabled = false
        spendLimitMonthlyCents = nil
        spendLimitUsedCents = nil
        spendLimitCurrency = nil
        spendLimitDisabledReason = nil
        spendLimitOutOfCredits = false
        planDisplayName = nil
        hasSessionLimit = false
        hasWeeklyLimit = false
        omelettePercent = nil
        omeletteResetDescription = nil
        promotionalOmelettePercent = nil
        promotionalOmeletteResetDescription = nil
        rateLimitTier = nil
        sessionResetDescription = ""
        weeklyResetDescription = ""
        sessionResetsAt = nil
        weeklyResetsAt = nil
        opusResetsAt = nil
        sonnetResetsAt = nil
        oauthAppsResetsAt = nil
        coworkResetsAt = nil
        extraUsageResetsAt = nil
        omeletteResetsAt = nil
        promotionalOmeletteResetsAt = nil
        lastUpdated = nil
        errorMessage = nil
        lastUsageData = nil
        isPacingWarning = false
        isServiceDown = false
        isUnauthorized = false
        consecutiveFailures = 0
    }

    // MARK: - Account Actions (used by views)

    /// Validates and adds (or upserts) an account. Used by the first-run onboarding view
    /// and by the "Add account" sheet. Throws on bad key / network / API errors so the
    /// caller can surface a message.
    ///
    /// For new accounts the `$activeId` Combine sink handles re-attach. For key rotation
    /// (same account ID), `setActive(sameId)` is a no-op so we re-attach manually.
    @discardableResult
    func addAccount(sessionKey: String) async throws -> Account {
        let previousActiveId = accountStore.activeId
        let account = try await accountStore.add(sessionKey: sessionKey)
        if account.id == previousActiveId {
            // Key rotation: setActive was a no-op so $activeId Combine sink won't fire.
            attachActiveAccount()
        } else {
            // New account: $activeId Combine sink will call attachActiveAccount().
            // Eagerly show loading so the view doesn't flash empty bars before Combine fires.
            isLoading = true
        }
        return account
    }

    /// Enable the synthetic demo account. Idempotent.
    @discardableResult
    func enableDemoAccount() -> Account {
        accountStore.addDemo()
    }

    /// Removes the active account; the next account in the list becomes active automatically.
    func removeActiveAccount() {
        guard let id = accountStore.activeId else { return }
        accountStore.remove(id: id)
    }

    func renameActiveAccount(_ newLabel: String) {
        guard let id = accountStore.activeId else { return }
        accountStore.rename(id, to: newLabel)
    }

    func setActiveAccount(_ id: String) {
        accountStore.setActive(id)
    }

    func testConnection(sessionKey: String) async throws {
        let client = ClawdAPIClient(sessionKey: sessionKey)
        _ = try await client.testConnection()
    }

    // MARK: - Fetch

    private var isDemoMode: Bool {
        accountStore.activeId == Account.demoId
    }

    func fetchUsage() {
        guard let scraper = scraper else { return }

        if isDemoMode {
            let data = makeDemoData()
            lastUsageData = data
            applyUsageData(data)
            lastUpdated = Date()
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let data = try await scraper.scrapeWithRetry()
                lastUsageData = data
                applyUsageData(data)
                lastUpdated = Date()
                if let id = accountStore.activeId {
                    accountStore.recordSnapshot(id: id, data: data)
                }
                consecutiveFailures = 0
                isUnauthorized = false
                if isServiceDown, let id = accountStore.activeId {
                    notificationManager.clearServiceDown(accountId: id)
                }
                isServiceDown = false

                if hasNoUsageSignal(data) {
                    errorMessage = "Could not read usage data. Session key may be expired."
                } else {
                    errorMessage = nil
                }

                evaluateFailover()
                adjustRefreshRate()
                await checkForUpdate()
            } catch ClawdAPIError.rateLimited {
                errorMessage = ClawdAPIError.rateLimited.localizedDescription
                consecutiveFailures += 1
                updateServiceDownStatus()
                rescheduleRefresh(interval: 60)
            } catch ClawdAPIError.unauthorized {
                consecutiveFailures = 0
                isServiceDown = false
                isUnauthorized = true
                errorMessage = ClawdAPIError.unauthorized.localizedDescription
            } catch {
                consecutiveFailures += 1
                updateServiceDownStatus()
                errorMessage = isServiceDown
                    ? "Clawd appears to be down. Retrying automatically..."
                    : error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Fetch only if enough time has passed since last fetch (for popover open)
    func fetchUsageIfStale() {
        accountStore.refreshInactivesIfStale()
        if let last = lastUpdated, Date().timeIntervalSince(last) < minFetchInterval {
            return
        }
        fetchUsage()
    }

    // MARK: - Update Check

    func checkForUpdate() async {
        guard let result = await updateChecker.check() else { return }
        let dismissed = UserDefaults.standard.string(forKey: "clawdephobia.dismissed_update_version") ?? ""
        guard result.version != dismissed else { return }
        await MainActor.run {
            updateAvailableVersion = result.version
            updateReleaseURL = result.releaseURL
        }
        notificationManager.sendLocal(
            title: "Clawdephobia update available",
            body: "Version \(result.version) is out — open the app to download"
        )
    }

    func dismissUpdate() {
        guard let version = updateAvailableVersion else { return }
        UserDefaults.standard.set(version, forKey: "clawdephobia.dismissed_update_version")
        updateAvailableVersion = nil
    }

    // MARK: - Settings Actions

    func setFailoverMode(_ mode: Int) {
        failoverMode = mode
        UserDefaults.standard.set(mode, forKey: "clawdephobia.failover_mode")
        if mode == 0 { pendingFailover = nil }
    }

    /// Confirm-mode actions, driven by the popover prompt.
    func acceptFailover() {
        guard let target = pendingFailover else { return }
        pendingFailover = nil
        accountStore.setActive(target.toId)
    }

    func dismissFailover() {
        pendingFailover = nil
    }

    // MARK: - Failover

    /// After a fresh fetch, if the active account is nearly out of usage, surface (or perform)
    /// a jump to the account with the most headroom, per `failoverMode`. Throttled to once per
    /// over-threshold episode via `failoverAlertedAccountId`.
    private func evaluateFailover() {
        guard failoverMode != 0, !isDemoMode, let activeId = accountStore.activeId else { return }

        let worst = max(sessionPercent, weeklyPercent)
        guard worst >= failoverTriggerThreshold else {
            if failoverAlertedAccountId == activeId { failoverAlertedAccountId = nil }
            if pendingFailover != nil { pendingFailover = nil }
            return
        }
        guard failoverAlertedAccountId != activeId else { return }
        guard let target = bestFailoverTarget(excluding: activeId) else { return }

        failoverAlertedAccountId = activeId
        let fromLabel = accountStore.account(for: activeId)?.label ?? "This account"
        let toLabel = accountStore.account(for: target.id)?.label ?? "another account"
        let pct = Int(worst * 100)

        switch failoverMode {
        case 3: // automatic
            notificationManager.sendLocal(
                title: "Switched to \(toLabel)",
                body: "\(fromLabel) hit \(pct)% — moved you to \(toLabel), which has the most headroom."
            )
            accountStore.setActive(target.id)
        case 2: // confirm
            pendingFailover = PendingFailover(fromLabel: fromLabel, toId: target.id,
                                              toLabel: toLabel, fromPercent: pct)
            notificationManager.sendLocal(
                title: "\(fromLabel) is almost out",
                body: "At \(pct)%. Open Clawdephobia to switch to \(toLabel)."
            )
        default: // 1 = manual (notify only)
            notificationManager.sendLocal(
                title: "\(fromLabel) is almost out",
                body: "At \(pct)%. \(toLabel) has the most headroom — switch from the menu when ready."
            )
        }
    }

    /// The other (non-demo) account with the most headroom — lowest max(session, weekly) — that
    /// still has room (below the trigger threshold). `nil` when no suitable account is known yet.
    private func bestFailoverTarget(excluding activeId: String) -> Account? {
        let scored: [(Account, Double)] = accountStore.accounts.compactMap { acc in
            guard acc.id != activeId, !acc.isDemo,
                  let peek = accountStore.peeks[acc.id] else { return nil }
            let worst = max(peek.sessionPercent, peek.weeklyPercent)
            guard worst < failoverTriggerThreshold else { return nil }
            return (acc, worst)
        }
        return scored.min(by: { $0.1 < $1.1 })?.0
    }

    func setMenuBarDisplayMode(_ mode: Int) {
        menuBarDisplayMode = mode
        UserDefaults.standard.set(mode, forKey: "clawdephobia.menu_bar_display")
    }

    func setMenuBarProgressStyle(_ style: Int) {
        menuBarProgressStyle = style
        UserDefaults.standard.set(style, forKey: "clawdephobia.menubar_progress_style")
    }

    func setViewProgressStyle(_ style: Int) {
        viewProgressStyle = style
        UserDefaults.standard.set(style, forKey: "clawdephobia.view_progress_style")
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
        UserDefaults.standard.set(notificationsEnabled, forKey: "clawdephobia.notifications_enabled")
        if !notificationsEnabled {
            notificationManager.reset()
        }
    }

    func setRefreshInterval(_ seconds: Int) {
        refreshInterval = seconds
        UserDefaults.standard.set(seconds, forKey: "clawdephobia.refresh_interval")
        startAutoRefresh()
    }

    func setWarningThreshold(_ value: Double) {
        warningThreshold = value
        UserDefaults.standard.set(value, forKey: "clawdephobia.warning_threshold")
        notificationManager.reset()
    }

    func setCriticalThreshold(_ value: Double) {
        criticalThreshold = value
        UserDefaults.standard.set(value, forKey: "clawdephobia.critical_threshold")
        notificationManager.reset()
    }

    func toggleNotifyOnReset() {
        notifyOnReset.toggle()
        UserDefaults.standard.set(notifyOnReset, forKey: "clawdephobia.notify_on_reset")
    }

    func togglePushNotifications() {
        pushNotificationsEnabled.toggle()
        UserDefaults.standard.set(pushNotificationsEnabled, forKey: "clawdephobia.push_enabled")
        syncPushSettings()
    }

    func setPushTopic(_ topic: String) {
        pushTopic = topic
        UserDefaults.standard.set(topic, forKey: "clawdephobia.push_topic")
        syncPushSettings()
    }

    func setPushServerURL(_ url: String) {
        pushServerURL = url
        UserDefaults.standard.set(url, forKey: "clawdephobia.push_server_url")
        syncPushSettings()
    }

    func sendTestPushNotification() {
        notificationManager.sendTestPush()
    }

    private func syncPushSettings() {
        notificationManager.pushEnabled = pushNotificationsEnabled
        notificationManager.pushTopic = pushTopic
        notificationManager.pushServerURL = pushServerURL
    }

    func sendTestNotification() {
        notificationManager.sendTest()
    }

    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        UserDefaults.standard.set(launchAtLogin, forKey: "clawdephobia.launch_at_login")
    }

    // MARK: - JSON Export

    func exportJSON() -> String {
        var dict: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "app": "Clawdephobia"
        ]
        if let acc = accountStore.activeAccount {
            dict["account"] = ["id": acc.id, "label": acc.label]
        }
        if let tier = rateLimitTier {
            dict["rate_limit_tier"] = tier
        }

        func limitDict(_ info: RateLimitInfo?) -> [String: Any]? {
            guard let info = info else { return nil }
            let iso = ISO8601DateFormatter()
            return [
                "utilization": info.percentUsed,
                "percent": Int(info.percentUsed * 100),
                "resets_at": iso.string(from: info.resetsAt)
            ]
        }

        if let data = lastUsageData {
            dict["five_hour"] = limitDict(data.fiveHour)
            dict["seven_day"] = limitDict(data.sevenDay)
            dict["seven_day_opus"] = limitDict(data.sevenDayOpus)
            dict["seven_day_sonnet"] = limitDict(data.sevenDaySonnet)
            dict["seven_day_oauth_apps"] = limitDict(data.sevenDayOAuthApps)
            dict["seven_day_cowork"] = limitDict(data.sevenDayCowork)
            dict["extra_usage"] = limitDict(data.extraUsage)
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clawdephobia-usage-\(dateStamp()).json"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            try? exportJSON().write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func resetAllData() {
        let keys = [
            "clawdephobia.setup_complete", "clawdephobia.menu_bar_display",
            "clawdephobia.icon_style",
            "clawdephobia.notifications_enabled", "clawdephobia.refresh_interval",
            "clawdephobia.warning_threshold", "clawdephobia.critical_threshold",
            "clawdephobia.launch_at_login",
            "clawdephobia.notify_on_reset",
            "clawdephobia.push_enabled", "clawdephobia.push_topic",
            "clawdephobia.push_server_url",
            // Multi-account keys
            "clawdephobia.accounts", "clawdephobia.active_account_id",
            "clawdephobia.accounts_schema_v1",
            // Legacy keys
            "claudemeter.setup_complete", "claudemeter.menu_bar_display",
            "claudemeter.notifications_enabled", "claudemeter.session_key",
            "claudemeter.compact_mode"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        accountStore.removeAll()
        KeychainHelper.delete(key: "session_key")
        try? SMAppService.mainApp.unregister()
        removeLegacyLaunchAgent()
        refreshTimer?.invalidate()
        refreshTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        clearActiveState()
        launchAtLogin = false
    }

    // MARK: - Private

    private func applyUsageData(_ data: ClawdUsageData) {
        // Helper: only assign if value actually changed (reduces SwiftUI churn)
        func updateIfNeeded<T: Equatable>(_ property: inout T, _ newValue: T) {
            if property != newValue { property = newValue }
        }

        // If the API returns a resetsAt in the past, the window has expired and a new
        // one hasn't started yet (e.g. 5-hour session before the first message). Treat
        // it as "no active window" — otherwise formatResetTime would emit "Resetting..."
        // on every refresh and the UI gets stuck on that label.
        //
        // `.distantFuture` is our sentinel for "no reset window reported" (some plans
        // return `resets_at: null` alongside utilization). Hide the reset label in that case.
        func resolvedReset(_ date: Date) -> (Date?, String) {
            if date == .distantFuture { return (nil, "") }
            if date.timeIntervalSinceNow <= 0 { return (nil, "") }
            return (date, formatResetTime(date))
        }

        if let session = data.fiveHour {
            updateIfNeeded(&hasSessionLimit, true)
            updateIfNeeded(&sessionPercent, session.percentUsed)
            let (date, desc) = resolvedReset(session.resetsAt)
            sessionResetsAt = date
            updateIfNeeded(&sessionResetDescription, desc)
        } else {
            updateIfNeeded(&hasSessionLimit, false)
            updateIfNeeded(&sessionPercent, 0)
            sessionResetsAt = nil
            updateIfNeeded(&sessionResetDescription, "")
        }

        if let weekly = data.sevenDay {
            updateIfNeeded(&hasWeeklyLimit, true)
            updateIfNeeded(&weeklyPercent, weekly.percentUsed)
            let (date, desc) = resolvedReset(weekly.resetsAt)
            weeklyResetsAt = date
            updateIfNeeded(&weeklyResetDescription, desc)
        } else {
            updateIfNeeded(&hasWeeklyLimit, false)
            updateIfNeeded(&weeklyPercent, 0)
            weeklyResetsAt = nil
            updateIfNeeded(&weeklyResetDescription, "")
        }

        if let opus = data.sevenDayOpus {
            updateIfNeeded(&opusPercent, opus.percentUsed)
            let (date, desc) = resolvedReset(opus.resetsAt)
            opusResetsAt = date
            updateIfNeeded(&opusResetDescription, desc)
        } else {
            opusPercent = nil
            opusResetDescription = nil
            opusResetsAt = nil
        }

        if let sonnet = data.sevenDaySonnet {
            updateIfNeeded(&sonnetPercent, sonnet.percentUsed)
            let (date, desc) = resolvedReset(sonnet.resetsAt)
            sonnetResetsAt = date
            updateIfNeeded(&sonnetResetDescription, desc)
        } else {
            sonnetPercent = nil
            sonnetResetDescription = nil
            sonnetResetsAt = nil
        }

        if let oauthApps = data.sevenDayOAuthApps {
            updateIfNeeded(&oauthAppsPercent, oauthApps.percentUsed)
            let (date, desc) = resolvedReset(oauthApps.resetsAt)
            oauthAppsResetsAt = date
            updateIfNeeded(&oauthAppsResetDescription, desc)
        } else {
            oauthAppsPercent = nil
            oauthAppsResetDescription = nil
            oauthAppsResetsAt = nil
        }

        if let cowork = data.sevenDayCowork {
            updateIfNeeded(&coworkPercent, cowork.percentUsed)
            let (date, desc) = resolvedReset(cowork.resetsAt)
            coworkResetsAt = date
            updateIfNeeded(&coworkResetDescription, desc)
        } else {
            coworkPercent = nil
            coworkResetDescription = nil
            coworkResetsAt = nil
        }

        if let extra = data.extraUsage {
            updateIfNeeded(&extraUsagePercent, extra.percentUsed)
            let (date, desc) = resolvedReset(extra.resetsAt)
            extraUsageResetsAt = date
            updateIfNeeded(&extraUsageResetDescription, desc)
        } else {
            extraUsagePercent = nil
            extraUsageResetDescription = nil
            extraUsageResetsAt = nil
        }

        if let omelette = data.sevenDayOmelette {
            updateIfNeeded(&omelettePercent, omelette.percentUsed)
            let (date, desc) = resolvedReset(omelette.resetsAt)
            omeletteResetsAt = date
            updateIfNeeded(&omeletteResetDescription, desc)
        } else {
            omelettePercent = nil
            omeletteResetDescription = nil
            omeletteResetsAt = nil
        }

        if let promo = data.sevenDayOmelettePromotional {
            updateIfNeeded(&promotionalOmelettePercent, promo.percentUsed)
            let (date, desc) = resolvedReset(promo.resetsAt)
            promotionalOmeletteResetsAt = date
            updateIfNeeded(&promotionalOmeletteResetDescription, desc)
        } else {
            promotionalOmelettePercent = nil
            promotionalOmeletteResetDescription = nil
            promotionalOmeletteResetsAt = nil
        }

        if let detail = data.extraUsageDetail {
            updateIfNeeded(&extraCreditsEnabled, detail.isEnabled)
            updateIfNeeded(&extraCreditsUsed, detail.usedCredits)
            updateIfNeeded(&extraCreditsMonthlyLimit, detail.monthlyLimit)
            updateIfNeeded(&extraCreditsCurrency, detail.currency)
            updateIfNeeded(&creditsResetDescription, nextMonthlyResetDescription())
        } else {
            extraCreditsEnabled = false
            extraCreditsUsed = nil
            extraCreditsMonthlyLimit = nil
            extraCreditsCurrency = nil
            creditsResetDescription = ""
        }

        if let prepaid = data.prepaidCredits {
            updateIfNeeded(&prepaidBalanceCents, Optional(prepaid.amountCents))
            updateIfNeeded(&prepaidCurrency, Optional(prepaid.currency))
        } else {
            prepaidBalanceCents = nil
            prepaidCurrency = nil
        }

        if let spend = data.overageSpendLimit {
            updateIfNeeded(&spendLimitEnabled, spend.isEnabled)
            updateIfNeeded(&spendLimitMonthlyCents, spend.monthlyLimitCents)
            updateIfNeeded(&spendLimitUsedCents, spend.usedCreditsCents)
            updateIfNeeded(&spendLimitCurrency, Optional(spend.currency))
            updateIfNeeded(&spendLimitDisabledReason, spend.disabledReason)
            updateIfNeeded(&spendLimitOutOfCredits, spend.outOfCredits)
        } else {
            spendLimitEnabled = false
            spendLimitMonthlyCents = nil
            spendLimitUsedCents = nil
            spendLimitCurrency = nil
            spendLimitDisabledReason = nil
            spendLimitOutOfCredits = false
        }

        updateIfNeeded(&rateLimitTier, data.rateLimitTier)
        updateIfNeeded(&planDisplayName, Self.mapPlanName(data.rateLimitTier))

        // Pacing indicator
        let newPacing = calculatePacingWarning(data)
        updateIfNeeded(&isPacingWarning, newPacing)

        // Notifications (label-prefixed by active account)
        if notificationsEnabled, let account = accountStore.activeAccount {
            func notify(_ label: String, _ percent: Double?) {
                guard let p = percent else { return }
                notificationManager.checkAndNotify(
                    accountId: account.id,
                    accountLabel: account.label,
                    label: label,
                    percentUsed: p,
                    warningThreshold: warningThreshold,
                    criticalThreshold: criticalThreshold,
                    notifyOnReset: notifyOnReset
                )
            }
            notify("5-hour session", sessionPercent)
            notify("7-day weekly", weeklyPercent)
            notify("Opus weekly", opusPercent)
            notify("Sonnet weekly", sonnetPercent)
        }
    }

    /// True when the API returned absolutely nothing useful — every rate limit nil,
    /// no credits, no promotional quota. That's our cue that the key is bad or the
    /// account isn't tracked. Enterprise (credit-only) plans still pass this check
    /// because their `extra_usage` carries `used_credits`.
    private func hasNoUsageSignal(_ data: ClawdUsageData) -> Bool {
        if data.fiveHour != nil || data.sevenDay != nil { return false }
        if data.sevenDayOpus != nil || data.sevenDaySonnet != nil { return false }
        if data.sevenDayOAuthApps != nil || data.sevenDayCowork != nil { return false }
        if data.sevenDayOmelette != nil || data.sevenDayOmelettePromotional != nil { return false }
        if data.extraUsage != nil { return false }
        if let detail = data.extraUsageDetail,
           detail.isEnabled || (detail.usedCredits ?? 0) > 0 || detail.monthlyLimit != nil {
            return false
        }
        return true
    }

    /// First day of next month, formatted "Resets MMM d" in the user's locale.
    /// Used as the subtitle for the pay-as-you-go credits row — the API does not
    /// return a reset date for `extra_usage`, but Anthropic resets the spend
    /// counter on the 1st of every calendar month.
    private func nextMonthlyResetDescription() -> String {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.month = (comps.month ?? 1) + 1
        comps.day = 1
        guard let next = cal.date(from: comps) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Resets " + fmt.string(from: next)
    }

    /// Returns true if the 5-hour session usage rate projects to exceed 100% before reset.
    private func calculatePacingWarning(_ data: ClawdUsageData) -> Bool {
        guard let session = data.fiveHour else { return false }
        let windowDuration: TimeInterval = 5 * 3600
        let windowStart = session.resetsAt.addingTimeInterval(-windowDuration)
        let elapsed = Date().timeIntervalSince(windowStart)

        // Need at least 10% of window elapsed and some actual usage
        guard elapsed > windowDuration * 0.1, session.percentUsed > 0.1 else { return false }

        let projectedUsage = session.percentUsed * (windowDuration / elapsed)
        return projectedUsage > 1.0
    }

    private func formatResetTime(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Resetting..." }

        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let days = hours / 24

        if days > 0 {
            let remainingHours = hours % 24
            return "Resets in \(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchUsage() }
        }
    }

    private func updateServiceDownStatus() {
        let wasDown = isServiceDown
        isServiceDown = consecutiveFailures >= serviceDownThreshold
        if isServiceDown && !wasDown && notificationsEnabled, let account = accountStore.activeAccount {
            notificationManager.sendServiceDown(accountId: account.id, accountLabel: account.label)
        }
    }

    /// Reschedule the next refresh after a specific delay (e.g., after 429)
    private func rescheduleRefresh(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fetchUsage()
                self?.startAutoRefresh()
            }
        }
    }

    /// Adjust polling frequency based on current usage level
    private func adjustRefreshRate() {
        let maxUsage = max(sessionPercent, weeklyPercent)
        let effectiveInterval: TimeInterval
        if maxUsage > 0.8 {
            effectiveInterval = 30
        } else if maxUsage > 0.5 {
            effectiveInterval = TimeInterval(refreshInterval) / 2
        } else {
            effectiveInterval = TimeInterval(refreshInterval)
        }

        let currentInterval = refreshTimer?.timeInterval ?? 0
        if abs(currentInterval - effectiveInterval) > 1 {
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.fetchUsage() }
            }
        }
    }

    // MARK: - Live Countdown

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateCountdowns() }
        }
    }

    func pauseCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    func resumeCountdownTimer() {
        updateCountdowns()
        startCountdownTimer()
    }

    private func updateCountdowns() {
        var shouldFetch = false

        if let date = sessionResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                sessionResetDescription = "Resetting..."
                if sessionPercent > 0 { sessionPercent = 0; shouldFetch = true }
                sessionResetsAt = nil
            } else {
                sessionResetDescription = formatResetTime(date)
            }
        }
        if let date = weeklyResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                weeklyResetDescription = "Resetting..."
                if weeklyPercent > 0 { weeklyPercent = 0; shouldFetch = true }
                weeklyResetsAt = nil
            } else {
                weeklyResetDescription = formatResetTime(date)
            }
        }
        if let date = opusResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                opusResetDescription = "Resetting..."
                if (opusPercent ?? 0) > 0 { opusPercent = 0; shouldFetch = true }
                opusResetsAt = nil
            } else {
                opusResetDescription = formatResetTime(date)
            }
        }
        if let date = sonnetResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                sonnetResetDescription = "Resetting..."
                if (sonnetPercent ?? 0) > 0 { sonnetPercent = 0; shouldFetch = true }
                sonnetResetsAt = nil
            } else {
                sonnetResetDescription = formatResetTime(date)
            }
        }
        if let date = oauthAppsResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                oauthAppsResetDescription = "Resetting..."
                if (oauthAppsPercent ?? 0) > 0 { oauthAppsPercent = 0; shouldFetch = true }
                oauthAppsResetsAt = nil
            } else {
                oauthAppsResetDescription = formatResetTime(date)
            }
        }
        if let date = coworkResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                coworkResetDescription = "Resetting..."
                if (coworkPercent ?? 0) > 0 { coworkPercent = 0; shouldFetch = true }
                coworkResetsAt = nil
            } else {
                coworkResetDescription = formatResetTime(date)
            }
        }
        if let date = extraUsageResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                extraUsageResetDescription = "Resetting..."
                if (extraUsagePercent ?? 0) > 0 { extraUsagePercent = 0; shouldFetch = true }
                extraUsageResetsAt = nil
            } else {
                extraUsageResetDescription = formatResetTime(date)
            }
        }
        if let date = omeletteResetsAt {
            if date.timeIntervalSinceNow <= 0 {
                omeletteResetDescription = "Resetting..."
                if (omelettePercent ?? 0) > 0 { omelettePercent = 0; shouldFetch = true }
                omeletteResetsAt = nil
            } else {
                omeletteResetDescription = formatResetTime(date)
            }
        }

        if shouldFetch && !isLoading {
            fetchUsage()
        }
    }

    // MARK: - System Event Observers

    private func observeSystemEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchUsage()
                self?.startAutoRefresh()
            }
        }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isSatisfied = path.status == .satisfied
            Task { @MainActor in
                if isSatisfied && self.wasNetworkUnsatisfied {
                    self.fetchUsageIfStale()
                }
                self.wasNetworkUnsatisfied = !isSatisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.clawdephobia.network"))
        networkMonitor = monitor
    }

    private func loadSettings() {
        notificationsEnabled = UserDefaults.standard.object(forKey: "clawdephobia.notifications_enabled") as? Bool ?? true
        menuBarDisplayMode = UserDefaults.standard.integer(forKey: "clawdephobia.menu_bar_display")
        menuBarProgressStyle = UserDefaults.standard.integer(forKey: "clawdephobia.menubar_progress_style")
        viewProgressStyle = UserDefaults.standard.integer(forKey: "clawdephobia.view_progress_style")
        refreshInterval = UserDefaults.standard.object(forKey: "clawdephobia.refresh_interval") as? Int ?? 300
        warningThreshold = UserDefaults.standard.object(forKey: "clawdephobia.warning_threshold") as? Double ?? 0.75
        criticalThreshold = UserDefaults.standard.object(forKey: "clawdephobia.critical_threshold") as? Double ?? 0.90
        launchAtLogin = SMAppService.mainApp.status == .enabled
        notifyOnReset = UserDefaults.standard.object(forKey: "clawdephobia.notify_on_reset") as? Bool ?? true
        failoverMode = UserDefaults.standard.object(forKey: "clawdephobia.failover_mode") as? Int ?? 1
        pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "clawdephobia.push_enabled")
        pushTopic = UserDefaults.standard.string(forKey: "clawdephobia.push_topic") ?? ""
        pushServerURL = UserDefaults.standard.string(forKey: "clawdephobia.push_server_url") ?? "https://ntfy.sh"
        syncPushSettings()
    }

    // MARK: - Version Reset

    private func resetIfNewVersion() {
        let key = "clawdephobia.data_schema_version"
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored < Self.dataSchemaVersion else { return }
        // Preserve any legacy single-account session key — AccountStore.migrateIfNeeded()
        // will pick it up from Keychain regardless of which UserDefaults are wiped.
        let allKeys = [
            "clawdephobia.setup_complete", "clawdephobia.menu_bar_display",
            "clawdephobia.icon_style",
            "clawdephobia.notifications_enabled", "clawdephobia.refresh_interval",
            "clawdephobia.warning_threshold", "clawdephobia.critical_threshold",
            "clawdephobia.launch_at_login", "clawdephobia.notify_on_reset",
            "clawdephobia.push_enabled", "clawdephobia.push_topic",
            "clawdephobia.push_server_url",
        ]
        allKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.set(Self.dataSchemaVersion, forKey: key)
    }

    // MARK: - Migration

    private func migrateAll() {
        KeychainHelper.migrateFromLegacyService(key: "session_key")

        let suffixes = [
            "setup_complete", "menu_bar_display", "menubar_progress_style",
            "view_progress_style", "icon_style",
            "notifications_enabled", "refresh_interval",
            "warning_threshold", "critical_threshold", "notify_on_reset",
            "push_enabled", "push_topic", "push_server_url",
            "launch_at_login", "data_schema_version",
        ]
        var migrations: [(old: String, new: String)] = [
            ("claudemeter.setup_complete", "clawdephobia.setup_complete"),
            ("claudemeter.menu_bar_display", "clawdephobia.menu_bar_display"),
            ("claudemeter.notifications_enabled", "clawdephobia.notifications_enabled"),
        ]
        for suffix in suffixes {
            migrations.append(("claudephobia.\(suffix)", "clawdephobia.\(suffix)"))
        }
        for m in migrations {
            if let val = UserDefaults.standard.object(forKey: m.old) {
                if UserDefaults.standard.object(forKey: m.new) == nil {
                    UserDefaults.standard.set(val, forKey: m.new)
                }
                UserDefaults.standard.removeObject(forKey: m.old)
            }
        }

        for legacyKey in ["claudemeter.session_key", "claudephobia.session_key"] {
            if let legacyValue = UserDefaults.standard.string(forKey: legacyKey) {
                KeychainHelper.save(key: "session_key", value: legacyValue)
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
        }

        removeLegacyLaunchAgent()
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func makeDemoData() -> ClawdUsageData {
        let now = Date()
        return ClawdUsageData(
            fiveHour:                    RateLimitInfo(percentUsed: 0.72, resetsAt: now.addingTimeInterval(3600 * 2.5)),
            sevenDay:                    RateLimitInfo(percentUsed: 0.45, resetsAt: now.addingTimeInterval(3600 * 52)),
            sevenDayOpus:                RateLimitInfo(percentUsed: 0.61, resetsAt: now.addingTimeInterval(3600 * 52)),
            sevenDaySonnet:              RateLimitInfo(percentUsed: 0.33, resetsAt: now.addingTimeInterval(3600 * 52)),
            sevenDayOAuthApps:           RateLimitInfo(percentUsed: 0.10, resetsAt: now.addingTimeInterval(3600 * 52)),
            sevenDayCowork:              RateLimitInfo(percentUsed: 0.05, resetsAt: now.addingTimeInterval(3600 * 52)),
            extraUsage:                  RateLimitInfo(percentUsed: 0.88, resetsAt: now.addingTimeInterval(3600 * 12)),
            extraUsageDetail:            ExtraUsageInfo(isEnabled: true, usedCredits: 12.34, monthlyLimit: 100.0, currency: "USD"),
            rateLimitTier:               "pro",
            sevenDayOmelette:            RateLimitInfo(percentUsed: 0.25, resetsAt: now.addingTimeInterval(3600 * 52)),
            sevenDayOmelettePromotional: nil,
            iguanaNecktie:               nil,
            prepaidCredits:              PrepaidCreditsInfo(amountCents: 179, currency: "USD"),
            overageSpendLimit:           OverageSpendLimitInfo(
                isEnabled: true,
                monthlyLimitCents: 3500,
                usedCreditsCents: 1234,
                currency: "USD",
                disabledReason: nil,
                outOfCredits: false,
                period: "monthly"
            )
        )
    }

    /// Maps Anthropic's opaque `rate_limit_tier` string into a user-facing
    /// plan name. Unknown tiers fall back to a title-cased version of the raw
    /// value with any `claude_` prefix stripped.
    private static let tierDisplayNames: [String: String] = [
        "free": "Free",
        "claude_free": "Free",
        "pro": "Pro",
        "claude_pro": "Pro",
        "max_5x": "Max 5×",
        "claude_max_5x": "Max 5×",
        "max_20x": "Max 20×",
        "claude_max_20x": "Max 20×",
        "team": "Team",
        "claude_team": "Team",
        "enterprise": "Enterprise",
        "claude_enterprise": "Enterprise"
    ]

    static func mapPlanName(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !raw.isEmpty else {
            return nil
        }
        if let mapped = tierDisplayNames[raw] { return mapped }
        let cleaned = raw.replacingOccurrences(of: "claude_", with: "")
        return cleaned.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    // MARK: - Legacy LaunchAgent Cleanup

    private func removeLegacyLaunchAgent() {
        guard !ProcessInfo.processInfo.environment.keys.contains("APP_SANDBOX_CONTAINER_ID") else { return }
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.claudemeter.app.plist").path
        try? FileManager.default.removeItem(atPath: path)
    }
}
