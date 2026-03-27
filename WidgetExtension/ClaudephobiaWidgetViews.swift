import SwiftUI
import WidgetKit

// MARK: - Colors matching the main app's dark theme

private extension Color {
    static let widgetBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let widgetAccent = Color(red: 222 / 255.0, green: 115 / 255.0, blue: 86 / 255.0)
    static let widgetDivider = Color.white.opacity(0.12)
}

// MARK: - macOS 14 container background compatibility shim

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(Color.widgetBackground, for: .widget)
        } else {
            background(Color.widgetBackground)
        }
    }
}

// MARK: - Top-level router

struct ClaudephobiaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClaudephobiaEntry

    var body: some View {
        Group {
            if let data = entry.data, data.isSetupComplete {
                switch family {
                case .systemMedium:
                    MediumWidgetView(data: data)
                default:
                    SmallWidgetView(data: data)
                }
            } else {
                SetupPromptView()
            }
        }
        .widgetContainerBackground()
    }
}

// MARK: - Small widget  (session + weekly)

struct SmallWidgetView: View {
    let data: WidgetSharedData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.widgetAccent)
                Text("Claudephobia")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
                if data.isPacingWarning {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
                if data.isServiceDown {
                    Image(systemName: "icloud.slash.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                }
            }

            Spacer(minLength: 8)

            WidgetUsageRow(
                label: "5-hour",
                percent: data.sessionPercent,
                resetDescription: data.sessionResetDescription
            )

            Spacer(minLength: 8)

            WidgetUsageRow(
                label: "7-day",
                percent: data.weeklyPercent,
                resetDescription: data.weeklyResetDescription
            )

            Spacer(minLength: 6)

            // Footer timestamp
            if let updated = data.lastUpdated {
                Text(relativeTimeString(updated))
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .padding(12)
    }
}

// MARK: - Medium widget  (session + weekly | opus + sonnet)

struct MediumWidgetView: View {
    let data: WidgetSharedData

    private var hasModelLimits: Bool {
        data.opusPercent != nil || data.sonnetPercent != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left column — always-present metrics
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.widgetAccent)
                    Text("Claudephobia")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                    if data.isPacingWarning {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    if data.isServiceDown {
                        Image(systemName: "icloud.slash.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                }

                Spacer(minLength: 10)

                WidgetUsageRow(
                    label: "5-hour session",
                    percent: data.sessionPercent,
                    resetDescription: data.sessionResetDescription
                )

                Spacer(minLength: 10)

                WidgetUsageRow(
                    label: "7-day weekly",
                    percent: data.weeklyPercent,
                    resetDescription: data.weeklyResetDescription
                )

                Spacer(minLength: 0)

                if let updated = data.lastUpdated {
                    Text(relativeTimeString(updated))
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.top, 6)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            // Divider
            Rectangle()
                .fill(Color.widgetDivider)
                .frame(width: 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)

            // Right column — per-model limits
            VStack(alignment: .leading, spacing: 0) {
                Text("Models")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))

                if hasModelLimits {
                    if let opus = data.opusPercent {
                        Spacer(minLength: 10)
                        WidgetUsageRow(label: "Opus", percent: opus, resetDescription: nil)
                    }
                    if let sonnet = data.sonnetPercent {
                        Spacer(minLength: 10)
                        WidgetUsageRow(label: "Sonnet", percent: sonnet, resetDescription: nil)
                    }
                } else {
                    Spacer(minLength: 8)
                    Text("No per-model\nlimits on\nyour plan")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
    }
}

// MARK: - Setup prompt (shown when isSetupComplete == false)

struct SetupPromptView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 22))
                .foregroundColor(.widgetAccent)
            Text("Open Claudephobia")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            Text("to set up your session key")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.45))
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

// MARK: - Reusable usage row

struct WidgetUsageRow: View {
    let label: String
    let percent: Double        // 0.0 – 1.0
    let resetDescription: String?

    private var barColor: Color {
        if percent >= 0.9 { return .red }
        if percent >= 0.7 { return .orange }
        return Color(red: 0.27, green: 0.56, blue: 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                Spacer(minLength: 4)
                Text("\(Int((percent * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(barColor)
            }

            // Progress bar — fixed height ZStack with GeometryReader for width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                GeometryReader { geo in
                    Capsule()
                        .fill(barColor)
                        .frame(
                            width: geo.size.width * CGFloat(min(1.0, max(0.0, percent))),
                            height: 4
                        )
                }
                .frame(height: 4)
            }

            if let reset = resetDescription, !reset.isEmpty {
                Text(reset)
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Helper

private func relativeTimeString(_ date: Date) -> String {
    let seconds = Int(-date.timeIntervalSinceNow)
    guard seconds >= 0 else { return "just now" }
    if seconds < 60 { return "just now" }
    let minutes = seconds / 60
    if minutes == 1 { return "1 min ago" }
    if minutes < 60 { return "\(minutes) min ago" }
    let hours = minutes / 60
    return hours == 1 ? "1 hr ago" : "\(hours) hrs ago"
}
