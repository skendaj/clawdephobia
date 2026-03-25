import AppKit
import Foundation

/// Sends native macOS notifications when usage crosses warning or critical thresholds,
/// and optionally when limits reset.
final class NotificationManager {
    private var sentKeys = Set<String>()

    /// Tracks previous percent values to detect resets (usage dropping significantly)
    private var previousPercents: [String: Double] = [:]

    func requestPermission() {
        // osascript notifications don't need permission
    }

    /// Check usage and fire notifications if thresholds are crossed.
    func checkAndNotify(
        label: String,
        percentUsed: Double,
        warningThreshold: Double,
        criticalThreshold: Double,
        notifyOnReset: Bool
    ) {
        let pct = Int(percentUsed * 100)
        let warnKey = "\(label)-warning"
        let critKey = "\(label)-critical"
        let resetKey = "\(label)-reset"

        // Threshold notifications
        if percentUsed >= criticalThreshold && !sentKeys.contains(critKey) {
            sentKeys.insert(critKey)
            send(
                title: "Claudephobia \u{2014} Critical",
                body: "\(label) at \(pct)%. You're about to hit your limit."
            )
        } else if percentUsed >= warningThreshold && !sentKeys.contains(warnKey) {
            sentKeys.insert(warnKey)
            send(
                title: "Claudephobia \u{2014} Warning",
                body: "\(label) at \(pct)%. Consider slowing down."
            )
        }

        // Reset detection: usage dropped from >=20% to <5% (limit restored)
        if notifyOnReset, let prev = previousPercents[label] {
            if prev >= 0.20 && percentUsed < 0.05 && !sentKeys.contains(resetKey) {
                sentKeys.insert(resetKey)
                send(
                    title: "Claudephobia \u{2014} Restored",
                    body: "\(label) has reset. You're good to go."
                )
            }
        }

        // Clear flags when usage drops below warning
        if percentUsed < warningThreshold {
            sentKeys.remove(warnKey)
            sentKeys.remove(critKey)
        }

        // Clear reset flag once usage climbs back up (so it can fire again next cycle)
        if percentUsed >= 0.05 {
            sentKeys.remove(resetKey)
        }

        previousPercents[label] = percentUsed
    }

    func sendTest() {
        send(
            title: "Claudephobia \u{2014} Test",
            body: "Notifications are working."
        )
    }

    func reset() {
        sentKeys.removeAll()
        previousPercents.removeAll()
    }

    // MARK: - Private

    private func send(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName

        // Attach the app icon so notifications show the Claudephobia icon
        if let iconPath = Self.appIconURL {
            notification.contentImage = NSImage(contentsOf: iconPath)
        }

        NSUserNotificationCenter.default.deliver(notification)
    }

    /// Resolves the app icon from the bundle or the source Resources directory.
    private static var appIconURL: URL? = {
        // When running as a .app bundle
        if let bundlePath = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return bundlePath
        }
        // When running the debug binary directly, look relative to the executable
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let projectRoot = execURL
            .deletingLastPathComponent() // debug/
            .deletingLastPathComponent() // .build/
        let resourceIcon = projectRoot.appendingPathComponent("Resources/AppIcon.icns")
        if FileManager.default.fileExists(atPath: resourceIcon.path) {
            return resourceIcon
        }
        return nil
    }()
}
