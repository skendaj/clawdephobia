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

    // Tier
    @Published var rateLimitTier: String?

    /// 0 = bars only, 1 = bars + text, 2 = bars + compact text
    @Published var menuBarDisplayMode: Int = 0

    @Published var isSetupComplete: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var showSettingsWindow: Bool = false
    @Published var pendingShareAction: ShareAction? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    /// True when using Claude faster than sustainable for the current window
    @Published var isPacingWarning: Bool = false

    /// True when Claude's service appears to be down (consecutive server/network failures)
    @Published var isServiceDown: Bool = false

    /// Refresh interval in seconds (60, 300, 600)
    @Published var refreshInterval: Int = 300

    /// Warning threshold (0.0–1.0)
    @Published var warningThreshold: Double = 0.75
    /// Critical threshold (0.0–1.0)
    @Published var criticalThreshold: Double = 0.90

    /// Notify when limits reset
    @Published var notifyOnReset: Bool = true

    /// Launch at login via SMAppService
    @Published var launchAtLogin: Bool = false

    // MARK: - Services

    private var scraper: UsageScraper?
    private var apiClient: ClaudeAPIClient?
    private let notificationManager = NotificationManager()
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private var networkMonitor: NWPathMonitor?
    private var wasNetworkUnsatisfied = false

    /// Raw reset dates for live countdown
    private var sessionResetsAt: Date?
    private var weeklyResetsAt: Date?
    private var opusResetsAt: Date?
    private var sonnetResetsAt: Date?
    private var oauthAppsResetsAt: Date?
    private var coworkResetsAt: Date?
    private var extraUsageResetsAt: Date?

    /// Minimum seconds between fetches (prevents hammering on popover open)
    private let minFetchInterval: TimeInterval = 30

    /// Consecutive server/network failure count for service-down detection
    private var consecutiveFailures = 0
    private let serviceDownThreshold = 3

    /// Stores the last fetched raw data for JSON export
    private var lastUsageData: ClaudeUsageData?

    // MARK: - Init

    /// Data schema version — bump this to force a reset on next launch
    private static let dataSchemaVersion = 2

    init() {
        migrateAll()
        resetIfNewVersion()
        loadSettings()
        if isSetupComplete, let key = storedSessionKey {
            scraper = UsageScraper(sessionKey: key)
            apiClient = ClaudeAPIClient(sessionKey: key)
            startAutoRefresh()
            fetchUsage()
        }
        startCountdownTimer()
        observeSystemEvents()
    }

    // MARK: - Setup

    func completeSetup(sessionKey: String) {
        storeSessionKey(sessionKey)
        scraper = UsageScraper(sessionKey: sessionKey)
        apiClient = ClaudeAPIClient(sessionKey: sessionKey)
        UserDefaults.standard.set(true, forKey: "claudephobia.setup_complete")
        isSetupComplete = true
        startAutoRefresh()
        fetchUsage()
    }

    func updateSessionKey(_ key: String) {
        storeSessionKey(key)
        scraper = UsageScraper(sessionKey: key)
        apiClient?.updateSessionKey(key)
        errorMessage = nil
        fetchUsage()
    }

    func clearSessionKey() {
        KeychainHelper.delete(key: "session_key")
        refreshTimer?.invalidate()
        refreshTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        scraper = nil
        apiClient = nil
        notificationManager.reset()
        sessionPercent = 0
        weeklyPercent = 0
        opusPercent = nil
        sonnetPercent = nil
        oauthAppsPercent = nil
        coworkPercent = nil
        extraUsagePercent = nil
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
        lastUpdated = nil
        errorMessage = nil
        lastUsageData = nil
        isPacingWarning = false
        isServiceDown = false
        consecutiveFailures = 0
        UserDefaults.standard.set(false, forKey: "claudephobia.setup_complete")
        isSetupComplete = false
    }

    func testConnection(sessionKey: String) async throws {
        let client = ClaudeAPIClient(sessionKey: sessionKey)
        _ = try await client.testConnection()
    }

    // MARK: - Debug

//    /// Temporarily fake service-down state for UI testing.
//    func debugToggleServiceDown() {
//        isServiceDown.toggle()
//        if isServiceDown {
//            errorMessage = "Claude appears to be down. Retrying automatically..."
//        } else {
//            errorMessage = nil
//        }
//    }

    // MARK: - Fetch

    func fetchUsage() {
        guard let scraper = scraper else { return }
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let data = try await scraper.scrapeWithRetry()
                lastUsageData = data
                applyUsageData(data)
                lastUpdated = Date()
                consecutiveFailures = 0
                isServiceDown = false

                if data.fiveHour == nil && data.sevenDay == nil {
                    errorMessage = "Could not read usage data. Session key may be expired."
                } else {
                    errorMessage = nil
                }

                // Adaptive polling: increase frequency when usage is high
                adjustRefreshRate()
            } catch ClaudeAPIError.rateLimited {
                errorMessage = ClaudeAPIError.rateLimited.localizedDescription
                consecutiveFailures += 1
                updateServiceDownStatus()
                // Back off for 60s on rate limit
                rescheduleRefresh(interval: 60)
            } catch ClaudeAPIError.unauthorized {
                // Auth errors are not service outages — reset counter
                consecutiveFailures = 0
                isServiceDown = false
                errorMessage = ClaudeAPIError.unauthorized.localizedDescription
            } catch {
                consecutiveFailures += 1
                updateServiceDownStatus()
                errorMessage = isServiceDown
                    ? "Claude appears to be down. Retrying automatically..."
                    : error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Fetch only if enough time has passed since last fetch (for popover open)
    func fetchUsageIfStale() {
        if let last = lastUpdated, Date().timeIntervalSince(last) < minFetchInterval {
            return
        }
        fetchUsage()
    }

    // MARK: - Settings Actions

    func setMenuBarDisplayMode(_ mode: Int) {
        menuBarDisplayMode = mode
        UserDefaults.standard.set(mode, forKey: "claudephobia.menu_bar_display")
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
        UserDefaults.standard.set(notificationsEnabled, forKey: "claudephobia.notifications_enabled")
        if !notificationsEnabled {
            notificationManager.reset()
        }
    }

    func setRefreshInterval(_ seconds: Int) {
        refreshInterval = seconds
        UserDefaults.standard.set(seconds, forKey: "claudephobia.refresh_interval")
        startAutoRefresh()
    }

    func setWarningThreshold(_ value: Double) {
        warningThreshold = value
        UserDefaults.standard.set(value, forKey: "claudephobia.warning_threshold")
        notificationManager.reset()
    }

    func setCriticalThreshold(_ value: Double) {
        criticalThreshold = value
        UserDefaults.standard.set(value, forKey: "claudephobia.critical_threshold")
        notificationManager.reset()
    }

    func toggleNotifyOnReset() {
        notifyOnReset.toggle()
        UserDefaults.standard.set(notifyOnReset, forKey: "claudephobia.notify_on_reset")
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
        UserDefaults.standard.set(launchAtLogin, forKey: "claudephobia.launch_at_login")
    }

    // MARK: - JSON Export

    func exportJSON() -> String {
        var dict: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "app": "Claudephobia"
        ]

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
        panel.nameFieldStringValue = "claudephobia-usage-\(dateStamp()).json"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            try? exportJSON().write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func resetAllData() {
        let keys = [
            "claudephobia.setup_complete", "claudephobia.menu_bar_display",
            "claudephobia.icon_style",
            "claudephobia.notifications_enabled", "claudephobia.refresh_interval",
            "claudephobia.warning_threshold", "claudephobia.critical_threshold",
            "claudephobia.launch_at_login",
            "claudephobia.notify_on_reset",
            // Legacy keys
            "claudemeter.setup_complete", "claudemeter.menu_bar_display",
            "claudemeter.notifications_enabled", "claudemeter.session_key",
            "claudemeter.compact_mode"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        KeychainHelper.delete(key: "session_key")
        try? SMAppService.mainApp.unregister()
        removeLegacyLaunchAgent()
        refreshTimer?.invalidate()
        refreshTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        scraper = nil
        apiClient = nil
        notificationManager.reset()
        sessionPercent = 0
        weeklyPercent = 0
        opusPercent = nil
        sonnetPercent = nil
        oauthAppsPercent = nil
        coworkPercent = nil
        extraUsagePercent = nil
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
        lastUpdated = nil
        errorMessage = nil
        lastUsageData = nil
        isSetupComplete = false
        launchAtLogin = false
        isPacingWarning = false
        isServiceDown = false
        consecutiveFailures = 0
    }

    // MARK: - Private

    private func applyUsageData(_ data: ClaudeUsageData) {
        // Helper: only assign if value actually changed (reduces SwiftUI churn)
        func updateIfNeeded<T: Equatable>(_ property: inout T, _ newValue: T) {
            if property != newValue { property = newValue }
        }

        if let session = data.fiveHour {
            updateIfNeeded(&sessionPercent, session.percentUsed)
            sessionResetsAt = session.resetsAt
            updateIfNeeded(&sessionResetDescription, formatResetTime(session.resetsAt))
        }

        if let weekly = data.sevenDay {
            updateIfNeeded(&weeklyPercent, weekly.percentUsed)
            weeklyResetsAt = weekly.resetsAt
            updateIfNeeded(&weeklyResetDescription, formatResetTime(weekly.resetsAt))
        }

        if let opus = data.sevenDayOpus {
            updateIfNeeded(&opusPercent, opus.percentUsed)
            opusResetsAt = opus.resetsAt
            updateIfNeeded(&opusResetDescription, formatResetTime(opus.resetsAt))
        } else {
            opusPercent = nil
            opusResetDescription = nil
            opusResetsAt = nil
        }

        if let sonnet = data.sevenDaySonnet {
            updateIfNeeded(&sonnetPercent, sonnet.percentUsed)
            sonnetResetsAt = sonnet.resetsAt
            updateIfNeeded(&sonnetResetDescription, formatResetTime(sonnet.resetsAt))
        } else {
            sonnetPercent = nil
            sonnetResetDescription = nil
            sonnetResetsAt = nil
        }

        if let oauthApps = data.sevenDayOAuthApps {
            updateIfNeeded(&oauthAppsPercent, oauthApps.percentUsed)
            oauthAppsResetsAt = oauthApps.resetsAt
            updateIfNeeded(&oauthAppsResetDescription, formatResetTime(oauthApps.resetsAt))
        } else {
            oauthAppsPercent = nil
            oauthAppsResetDescription = nil
            oauthAppsResetsAt = nil
        }

        if let cowork = data.sevenDayCowork {
            updateIfNeeded(&coworkPercent, cowork.percentUsed)
            coworkResetsAt = cowork.resetsAt
            updateIfNeeded(&coworkResetDescription, formatResetTime(cowork.resetsAt))
        } else {
            coworkPercent = nil
            coworkResetDescription = nil
            coworkResetsAt = nil
        }

        if let extra = data.extraUsage {
            updateIfNeeded(&extraUsagePercent, extra.percentUsed)
            extraUsageResetsAt = extra.resetsAt
            updateIfNeeded(&extraUsageResetDescription, formatResetTime(extra.resetsAt))
        } else {
            extraUsagePercent = nil
            extraUsageResetDescription = nil
            extraUsageResetsAt = nil
        }

        updateIfNeeded(&rateLimitTier, data.rateLimitTier)

        // Pacing indicator
        let newPacing = calculatePacingWarning(data)
        updateIfNeeded(&isPacingWarning, newPacing)

        // Notifications
        if notificationsEnabled {
            notificationManager.checkAndNotify(
                label: "5-hour session",
                percentUsed: sessionPercent,
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                notifyOnReset: notifyOnReset
            )
            notificationManager.checkAndNotify(
                label: "7-day weekly",
                percentUsed: weeklyPercent,
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                notifyOnReset: notifyOnReset
            )
            if let opus = opusPercent {
                notificationManager.checkAndNotify(
                    label: "Opus weekly",
                    percentUsed: opus,
                    warningThreshold: warningThreshold,
                    criticalThreshold: criticalThreshold,
                    notifyOnReset: notifyOnReset
                )
            }
            if let sonnet = sonnetPercent {
                notificationManager.checkAndNotify(
                    label: "Sonnet weekly",
                    percentUsed: sonnet,
                    warningThreshold: warningThreshold,
                    criticalThreshold: criticalThreshold,
                    notifyOnReset: notifyOnReset
                )
            }
        }
    }

    /// Returns true if the 5-hour session usage rate projects to exceed 100% before reset.
    private func calculatePacingWarning(_ data: ClaudeUsageData) -> Bool {
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
            self?.fetchUsage()
        }
    }

    private func updateServiceDownStatus() {
        let wasDown = isServiceDown
        isServiceDown = consecutiveFailures >= serviceDownThreshold
        // Notify once when transitioning to service-down state
        if isServiceDown && !wasDown && notificationsEnabled {
            notificationManager.sendServiceDown()
        }
    }

    /// Reschedule the next refresh after a specific delay (e.g., after 429)
    private func rescheduleRefresh(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.fetchUsage()
            self?.startAutoRefresh()
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

        // Only restart timer if interval actually changed
        let currentInterval = refreshTimer?.timeInterval ?? 0
        if abs(currentInterval - effectiveInterval) > 1 {
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
                self?.fetchUsage()
            }
        }
    }

    // MARK: - Live Countdown

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCountdowns()
        }
    }

    private func updateCountdowns() {
        if let date = sessionResetsAt {
            sessionResetDescription = formatResetTime(date)
        }
        if let date = weeklyResetsAt {
            weeklyResetDescription = formatResetTime(date)
        }
        if let date = opusResetsAt {
            opusResetDescription = formatResetTime(date)
        }
        if let date = sonnetResetsAt {
            sonnetResetDescription = formatResetTime(date)
        }
        if let date = oauthAppsResetsAt {
            oauthAppsResetDescription = formatResetTime(date)
        }
        if let date = coworkResetsAt {
            coworkResetDescription = formatResetTime(date)
        }
        if let date = extraUsageResetsAt {
            extraUsageResetDescription = formatResetTime(date)
        }
    }

    // MARK: - System Event Observers

    private func observeSystemEvents() {
        // Refresh on wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchUsage()
            self?.startAutoRefresh() // Reset timer cadence after wake
        }

        // Refresh on network reconnect
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isSatisfied = path.status == .satisfied
            if isSatisfied && self.wasNetworkUnsatisfied {
                DispatchQueue.main.async {
                    self.fetchUsageIfStale()
                }
            }
            self.wasNetworkUnsatisfied = !isSatisfied
        }
        monitor.start(queue: DispatchQueue(label: "com.claudephobia.network"))
        networkMonitor = monitor
    }

    private func loadSettings() {
        isSetupComplete = UserDefaults.standard.bool(forKey: "claudephobia.setup_complete")
        notificationsEnabled = UserDefaults.standard.object(forKey: "claudephobia.notifications_enabled") as? Bool ?? true
        menuBarDisplayMode = UserDefaults.standard.integer(forKey: "claudephobia.menu_bar_display")
        refreshInterval = UserDefaults.standard.object(forKey: "claudephobia.refresh_interval") as? Int ?? 300
        warningThreshold = UserDefaults.standard.object(forKey: "claudephobia.warning_threshold") as? Double ?? 0.75
        criticalThreshold = UserDefaults.standard.object(forKey: "claudephobia.critical_threshold") as? Double ?? 0.90
        launchAtLogin = SMAppService.mainApp.status == .enabled
        notifyOnReset = UserDefaults.standard.object(forKey: "claudephobia.notify_on_reset") as? Bool ?? true
    }

    // MARK: - Version Reset

    private func resetIfNewVersion() {
        let key = "claudephobia.data_schema_version"
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored < Self.dataSchemaVersion else { return }

        // Preserve the session key so users don't have to re-enter it
        let savedKey = storedSessionKey

        // Wipe all UserDefaults
        let allKeys = [
            "claudephobia.setup_complete", "claudephobia.menu_bar_display",
            "claudephobia.icon_style",
            "claudephobia.notifications_enabled", "claudephobia.refresh_interval",
            "claudephobia.warning_threshold", "claudephobia.critical_threshold",
            "claudephobia.launch_at_login", "claudephobia.notify_on_reset",
        ]
        allKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // Restore session key and mark setup complete if we had one
        if let savedKey = savedKey {
            storeSessionKey(savedKey)
            UserDefaults.standard.set(true, forKey: "claudephobia.setup_complete")
        }

        UserDefaults.standard.set(Self.dataSchemaVersion, forKey: key)
    }

    // MARK: - Migration

    private func migrateAll() {
        KeychainHelper.migrateFromLegacyService(key: "session_key")

        let migrations: [(old: String, new: String)] = [
            ("claudemeter.setup_complete", "claudephobia.setup_complete"),
            ("claudemeter.menu_bar_display", "claudephobia.menu_bar_display"),
            ("claudemeter.notifications_enabled", "claudephobia.notifications_enabled"),
        ]
        for m in migrations {
            if let val = UserDefaults.standard.object(forKey: m.old) {
                if UserDefaults.standard.object(forKey: m.new) == nil {
                    UserDefaults.standard.set(val, forKey: m.new)
                }
                UserDefaults.standard.removeObject(forKey: m.old)
            }
        }

        if let legacyKey = UserDefaults.standard.string(forKey: "claudemeter.session_key") {
            KeychainHelper.save(key: "session_key", value: legacyKey)
            UserDefaults.standard.removeObject(forKey: "claudemeter.session_key")
        }

        removeLegacyLaunchAgent()
    }

    private var storedSessionKey: String? {
        KeychainHelper.load(key: "session_key")
    }

    private func storeSessionKey(_ key: String) {
        KeychainHelper.save(key: "session_key", value: key)
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Legacy LaunchAgent Cleanup

    private func removeLegacyLaunchAgent() {
        // Skip in sandboxed builds — ~/Library/LaunchAgents is inaccessible
        guard !ProcessInfo.processInfo.environment.keys.contains("APP_SANDBOX_CONTAINER_ID") else { return }
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.claudephobia.app.plist").path
        try? FileManager.default.removeItem(atPath: path)
    }
}
