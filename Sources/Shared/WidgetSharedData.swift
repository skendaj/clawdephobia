import Foundation

// MARK: - Shared constants

enum WidgetSharing {
    static let appGroupID = "group.com.claudephobia.app"
    static let defaultsKey = "widget_data_v1"
}

// MARK: - Data model shared between main app and widget extension

/// All values are 0.0–1.0 fractions (matching RateLimitInfo.percentUsed).
struct WidgetSharedData: Codable {
    var sessionPercent: Double
    var weeklyPercent: Double
    var opusPercent: Double?
    var sonnetPercent: Double?
    var isServiceDown: Bool
    var isPacingWarning: Bool
    var isSetupComplete: Bool
    var lastUpdated: Date?
    var sessionResetDescription: String
    var weeklyResetDescription: String
}

// MARK: - App Group UserDefaults persistence

extension WidgetSharedData {
    /// Called by the main app after every successful data fetch.
    func persist() {
        guard let defaults = UserDefaults(suiteName: WidgetSharing.appGroupID),
              let encoded = try? JSONEncoder().encode(self)
        else { return }
        defaults.set(encoded, forKey: WidgetSharing.defaultsKey)
    }

    /// Called by the widget extension's TimelineProvider.
    static func load() -> WidgetSharedData? {
        guard
            let defaults = UserDefaults(suiteName: WidgetSharing.appGroupID),
            let data = defaults.data(forKey: WidgetSharing.defaultsKey),
            let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data)
        else { return nil }
        return decoded
    }
}
