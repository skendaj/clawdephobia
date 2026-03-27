import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ClaudephobiaEntry: TimelineEntry {
    let date: Date
    /// nil means the main app has never written data (first launch / no session key yet)
    let data: WidgetSharedData?
}

// MARK: - Timeline Provider

struct ClaudephobiaProvider: TimelineProvider {
    typealias Entry = ClaudephobiaEntry

    func placeholder(in context: Context) -> ClaudephobiaEntry {
        ClaudephobiaEntry(
            date: Date(),
            data: WidgetSharedData(
                sessionPercent: 0.62,
                weeklyPercent: 0.35,
                opusPercent: 0.20,
                sonnetPercent: nil,
                isServiceDown: false,
                isPacingWarning: false,
                isSetupComplete: true,
                lastUpdated: Date(),
                sessionResetDescription: "Resets in 2h 14m",
                weeklyResetDescription: "Resets in 4d 8h"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudephobiaEntry) -> Void) {
        completion(ClaudephobiaEntry(date: Date(), data: WidgetSharedData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudephobiaEntry>) -> Void) {
        let now = Date()
        let entry = ClaudephobiaEntry(date: now, data: WidgetSharedData.load())

        // Refresh every 15 minutes as a fallback when the main app isn't running.
        // The main app also calls WidgetCenter.shared.reloadAllTimelines() after every
        // successful fetch, which bypasses this schedule for near-realtime updates.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget Declaration

struct ClaudephobiaWidget: Widget {
    let kind = "ClaudephobiaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudephobiaProvider()) { entry in
            ClaudephobiaWidgetView(entry: entry)
        }
        .configurationDisplayName("Claudephobia")
        .description("Monitor your Claude AI usage limits.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
