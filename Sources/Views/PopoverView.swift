import SwiftUI

extension Color {
    static let accent = Color(red: 0xDE / 255.0, green: 0x73 / 255.0, blue: 0x56 / 255.0)
}

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        if viewModel.isSetupComplete {
            usageView
        } else {
            setupView
        }
    }

    // MARK: - Setup

    @State private var sessionKey: String = ""
    @State private var isTesting: Bool = false
    @State private var errorMessage: String? = nil

    private var setupView: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            AppIconView(size: 48)

            Text("Claudephobia")
                .font(.headline)

            Text("Fear of hitting Claude limits")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()

            Text("Paste your session key to get started.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SecureField("sk-ant-sid01-...", text: $sessionKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))

            VStack(alignment: .leading, spacing: 3) {
                Text("How to get it:")
                    .font(.caption2)
                    .fontWeight(.medium)
                Text("1. Open claude.ai in your browser")
                Text("2. DevTools (Cmd+Opt+I) \u{2192} Application")
                Text("3. Cookies \u{2192} claude.ai \u{2192} sessionKey")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("No cost. Uses your existing session cookie.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(2)
            }

            Button(action: connect) {
                ZStack {
                    Text("Connect").opacity(isTesting ? 0 : 1)
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))
            .disabled(sessionKey.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func connect() {
        let key = sessionKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        isTesting = true
        errorMessage = nil
        sessionKey = ""

        let client = ClaudeAPIClient(sessionKey: key)
        Task { @MainActor in
            do {
                _ = try await client.testConnection()
                viewModel.completeSetup(sessionKey: key)
            } catch {
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }

    // MARK: - Usage View

    private var usageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    AppIconView(size: 14)
                    Text("Claudephobia")
                        .font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                Button(action: { viewModel.showSettingsWindow = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            // 5-hour session
            usageRow(
                title: "5-hour session",
                percent: viewModel.sessionPercent,
                resetDescription: viewModel.sessionResetDescription,
                tint: barColor(viewModel.sessionPercent)
            )

            Divider().padding(.vertical, 10)

            // 7-day weekly
            usageRow(
                title: "7-day weekly",
                percent: viewModel.weeklyPercent,
                resetDescription: viewModel.weeklyResetDescription,
                tint: barColor(viewModel.weeklyPercent)
            )

            // Model-specific limits (only shown when available)
            if let opusPct = viewModel.opusPercent {
                Divider().padding(.vertical, 10)
                usageRow(
                    title: "Weekly \u{2014} Opus",
                    percent: opusPct,
                    resetDescription: viewModel.opusResetDescription ?? "",
                    tint: barColor(opusPct)
                )
            }

            if let sonnetPct = viewModel.sonnetPercent {
                Divider().padding(.vertical, 10)
                usageRow(
                    title: "Weekly \u{2014} Sonnet",
                    percent: sonnetPct,
                    resetDescription: viewModel.sonnetResetDescription ?? "",
                    tint: barColor(sonnetPct)
                )
            }

            // OAuth Apps usage
            if let oauthPct = viewModel.oauthAppsPercent {
                Divider().padding(.vertical, 10)
                usageRow(
                    title: "Weekly \u{2014} OAuth Apps",
                    percent: oauthPct,
                    resetDescription: viewModel.oauthAppsResetDescription ?? "",
                    tint: barColor(oauthPct)
                )
            }

            // Cowork usage
            if let coworkPct = viewModel.coworkPercent {
                Divider().padding(.vertical, 10)
                usageRow(
                    title: "Weekly \u{2014} Cowork",
                    percent: coworkPct,
                    resetDescription: viewModel.coworkResetDescription ?? "",
                    tint: barColor(coworkPct)
                )
            }

            // Extra usage
            if let extraPct = viewModel.extraUsagePercent {
                Divider().padding(.vertical, 10)
                usageRow(
                    title: "Extra usage",
                    percent: extraPct,
                    resetDescription: viewModel.extraUsageResetDescription ?? "",
                    tint: .purple
                )
            }

            Divider().padding(.vertical, 10)

            // Service down banner
            if viewModel.isServiceDown {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.slash.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude service appears down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        Text("Showing last known data. Retrying automatically.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
                .padding(.bottom, 8)
            }

            // Error
            if let error = viewModel.errorMessage, !viewModel.isServiceDown {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
                .padding(.bottom, 8)
            }

            // Footer
            HStack(spacing: 8) {
                if let updated = viewModel.lastUpdated {
                    Text(timeAgo(updated))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
                Spacer()

//                // DEBUG: Toggle service down
//                Button(action: { viewModel.debugToggleServiceDown() }) {
//                    Image(systemName: "ladybug.fill")
//                        .font(.system(size: 12))
//                        .foregroundColor(.red.opacity(0.5))
//                }
//                .buttonStyle(.plain)
//                .help("Debug: Toggle service down")

                Button(action: { viewModel.clearSessionKey() }) {
                    Label("Clear Key", systemImage: "key.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear session key and return to setup")

                Button(action: { viewModel.fetchUsage() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Usage Row

    private func usageRow(title: String, percent: Double, resetDescription: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
            }

            UsageProgressBar(value: percent, tint: tint)
                .frame(height: 6)

            if !resetDescription.isEmpty {
                Text(resetDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func barColor(_ percent: Double) -> Color {
        if percent >= 0.9 { return .red }
        if percent >= 0.7 { return .orange }
        return .blue
    }

    private func tierDisplayName(_ tier: String) -> String {
        let lower = tier.lowercased()
        if lower.contains("max_20x") || lower.contains("max20x") { return "Claude Max 20x Plan" }
        if lower.contains("max_5x") || lower.contains("max5x") { return "Claude Max 5x Plan" }
        if lower.contains("max") { return "Claude Max Plan" }
        if lower.contains("pro") { return "Claude Pro Plan" }
        if lower.contains("team") { return "Claude Team Plan" }
        if lower.contains("enterprise") { return "Claude Enterprise Plan" }
        if lower.contains("free") || lower.contains("default") { return "Claude Free Plan" }
        // Fallback: clean up the raw string
        return tier.replacingOccurrences(of: "_", with: " ").capitalized + " Plan"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes == 1 { return "1 min ago" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours == 1 { return "1 hr ago" }
        return "\(hours) hr ago"
    }
}

// MARK: - Progress Bar

struct AppIconView: View {
    var size: CGFloat = 48

    private static let cachedImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 256, height: 256)
        return image
    }()

    var body: some View {
        Group {
            if let nsImage = Self.cachedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Progress Bar

struct UsageProgressBar: View {
    let value: Double
    var tint: Color = .blue

    private var isOverflow: Bool { value > 1.0 }
    private var safeValue: Double { value.isFinite ? value : 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))

                if isOverflow {
                    // Full bar with striped pattern to indicate overflow
                    OverflowStripes(tint: tint)
                        .clipShape(Capsule())
                } else {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, geo.size.width * CGFloat(min(1, safeValue))))
                }
            }
        }
    }
}

// Striped pattern for overflow bars using simple SwiftUI shapes
struct OverflowStripes: View {
    let tint: Color

    var body: some View {
        ZStack {
            tint
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 3)
                        .rotationEffect(.degrees(-45))
                }
            }
        }
    }
}
