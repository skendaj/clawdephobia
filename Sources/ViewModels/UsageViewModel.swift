import Foundation
import Combine
import AppKit

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

    /// Refresh interval in seconds (60, 300, 600)
    @Published var refreshInterval: Int = 300

    /// Warning threshold (0.0–1.0)
    @Published var warningThreshold: Double = 0.75
    /// Critical threshold (0.0–1.0)
    @Published var criticalThreshold: Double = 0.90

    /// Notify when limits reset
    @Published var notifyOnReset: Bool = true

    /// Launch at login via LaunchAgent
    @Published var launchAtLogin: Bool = false

    // MARK: - Services

    private var scraper: UsageScraper?
    private var apiClient: ClaudeAPIClient?
    private let notificationManager = NotificationManager()
    private var refreshTimer: Timer?

    /// Stores the last fetched raw data for JSON export
    private var lastUsageData: ClaudeUsageData?

    // MARK: - Init

    init() {
        migrateAll()
        loadSettings()
        if isSetupComplete, let key = storedSessionKey {
            scraper = UsageScraper(sessionKey: key)
            apiClient = ClaudeAPIClient(sessionKey: key)
            startAutoRefresh()
            fetchUsage()
        }
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
        lastUpdated = nil
        errorMessage = nil
        lastUsageData = nil
        isPacingWarning = false
        UserDefaults.standard.set(false, forKey: "claudephobia.setup_complete")
        isSetupComplete = false
    }

    func testConnection(sessionKey: String) async throws {
        let client = ClaudeAPIClient(sessionKey: sessionKey)
        _ = try await client.testConnection()
    }

    // MARK: - Fetch

    func fetchUsage() {
        guard let scraper = scraper else { return }
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let data = try await scraper.scrape()
                lastUsageData = data
                applyUsageData(data)
                lastUpdated = Date()

                if data.fiveHour == nil && data.sevenDay == nil {
                    errorMessage = "Could not read usage data. Session key may be expired."
                } else {
                    errorMessage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
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
        launchAtLogin.toggle()
        UserDefaults.standard.set(launchAtLogin, forKey: "claudephobia.launch_at_login")
        if launchAtLogin {
            installLaunchAgent()
        } else {
            removeLaunchAgent()
        }
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
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
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
        removeLaunchAgent()
        refreshTimer?.invalidate()
        refreshTimer = nil
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
        lastUpdated = nil
        errorMessage = nil
        lastUsageData = nil
        isSetupComplete = false
        launchAtLogin = false
        isPacingWarning = false
    }

    // MARK: - Private

    private func applyUsageData(_ data: ClaudeUsageData) {
        if let session = data.fiveHour {
            sessionPercent = session.percentUsed
            sessionResetDescription = formatResetTime(session.resetsAt)
        }

        if let weekly = data.sevenDay {
            weeklyPercent = weekly.percentUsed
            weeklyResetDescription = formatResetTime(weekly.resetsAt)
        }

        if let opus = data.sevenDayOpus {
            opusPercent = opus.percentUsed
            opusResetDescription = formatResetTime(opus.resetsAt)
        } else {
            opusPercent = nil
            opusResetDescription = nil
        }

        if let sonnet = data.sevenDaySonnet {
            sonnetPercent = sonnet.percentUsed
            sonnetResetDescription = formatResetTime(sonnet.resetsAt)
        } else {
            sonnetPercent = nil
            sonnetResetDescription = nil
        }

        if let oauthApps = data.sevenDayOAuthApps {
            oauthAppsPercent = oauthApps.percentUsed
            oauthAppsResetDescription = formatResetTime(oauthApps.resetsAt)
        } else {
            oauthAppsPercent = nil
            oauthAppsResetDescription = nil
        }

        if let cowork = data.sevenDayCowork {
            coworkPercent = cowork.percentUsed
            coworkResetDescription = formatResetTime(cowork.resetsAt)
        } else {
            coworkPercent = nil
            coworkResetDescription = nil
        }

        if let extra = data.extraUsage {
            extraUsagePercent = extra.percentUsed
            extraUsageResetDescription = formatResetTime(extra.resetsAt)
        } else {
            extraUsagePercent = nil
            extraUsageResetDescription = nil
        }

        rateLimitTier = data.rateLimitTier

        // Pacing indicator
        isPacingWarning = calculatePacingWarning(data)

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

    private func loadSettings() {
        isSetupComplete = UserDefaults.standard.bool(forKey: "claudephobia.setup_complete")
        notificationsEnabled = UserDefaults.standard.object(forKey: "claudephobia.notifications_enabled") as? Bool ?? true
        menuBarDisplayMode = UserDefaults.standard.integer(forKey: "claudephobia.menu_bar_display")
        refreshInterval = UserDefaults.standard.object(forKey: "claudephobia.refresh_interval") as? Int ?? 300
        warningThreshold = UserDefaults.standard.object(forKey: "claudephobia.warning_threshold") as? Double ?? 0.75
        criticalThreshold = UserDefaults.standard.object(forKey: "claudephobia.critical_threshold") as? Double ?? 0.90
        launchAtLogin = UserDefaults.standard.bool(forKey: "claudephobia.launch_at_login")
        notifyOnReset = UserDefaults.standard.object(forKey: "claudephobia.notify_on_reset") as? Bool ?? true
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

    // MARK: - LaunchAgent

    private var launchAgentDir: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents").path
    }

    private var launchAgentPath: String {
        "\(launchAgentDir)/com.claudephobia.app.plist"
    }

    private func installLaunchAgent() {
        let execPath = ProcessInfo.processInfo.arguments[0]

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.claudephobia.app</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(execPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        try? FileManager.default.createDirectory(atPath: launchAgentDir,
                                                  withIntermediateDirectories: true)
        try? plist.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(atPath: launchAgentPath)
    }
}
