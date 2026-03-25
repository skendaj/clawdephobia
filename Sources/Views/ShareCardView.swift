import SwiftUI
import AppKit

// MARK: - Data Model

struct ShareCardData {
    struct Limit {
        let label: String
        let percent: Double
        let resetDescription: String
    }

    let limits: [Limit]
    let tier: String?
    let isPacing: Bool
    let timestamp: Date
}

// MARK: - Share Card View

struct ShareCardView: View {
    let data: ShareCardData

    // Claude product colors (flat, no gradients)
    private let bg = Color(red: 0.169, green: 0.161, blue: 0.149)            // #2B2926
    private let surface = Color(red: 0.200, green: 0.192, blue: 0.176)       // #333130
    private let terracotta = Color(red: 0.851, green: 0.467, blue: 0.341)    // #D97757
    private let cream = Color(red: 0.910, green: 0.878, blue: 0.831)         // #E8E0D4
    private let secondary = Color(red: 0.545, green: 0.514, blue: 0.475)     // #8B8379
    private let line = Color(red: 0.239, green: 0.220, blue: 0.196)          // #3D3832
    private let barBg = Color(red: 0.208, green: 0.196, blue: 0.180)         // #35322E
    private let red = Color(red: 0.906, green: 0.298, blue: 0.235)           // #E74C3C
    private let orange = Color(red: 0.925, green: 0.584, blue: 0.286)        // #EC9549

    private let cardWidth: CGFloat = 440

    private var worstPercent: Double {
        data.limits.map(\.percent).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.bottom, 28)

            // Tags
            tags
                .padding(.bottom, 16)

            // Hero number
            hero
                .padding(.bottom, 28)

            // Divider
            Rectangle().fill(line).frame(height: 1)

            // Limits
            limits
                .padding(.vertical, 24)

            // Pacing
            if data.isPacing {
                pacing
                    .padding(.bottom, 20)
            }

            // Divider
            Rectangle().fill(line).frame(height: 1)

            // Footer
            footer
                .padding(.top, 20)
        }
        .padding(32)
        .frame(width: cardWidth)
        .background(bg)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Claudephobia")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(cream)
            Text("Usage Report")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(secondary)
        }
    }

    // MARK: - Tags

    private var tags: some View {
        HStack(spacing: 0) {
            if let tier = data.tier {
                Text(tierName(tier))
                    .foregroundColor(secondary)
                Text("  /  ")
                    .foregroundColor(line)
            }
            Text(statusLabel)
                .foregroundColor(statusColor)
            Text("  /  ")
                .foregroundColor(line)
            Text(worstLimitLabel)
                .foregroundColor(secondary)
        }
        .font(.system(size: 11, weight: .medium))
        .textCase(.uppercase)
        .tracking(0.5)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(Int(worstPercent * 100))")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(heroColor)
                Text("%")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(heroColor.opacity(0.6))
                    .offset(y: 2)
                Text("  used")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(secondary)
                    .offset(y: -2)
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(barBg)
                    if worstPercent > 1.0 {
                        OverflowStripes(tint: heroColor)
                    } else {
                        Rectangle()
                            .fill(heroColor)
                            .frame(width: max(0, geo.size.width * CGFloat(worstPercent)))
                    }
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Limits

    private var limits: some View {
        VStack(spacing: 18) {
            ForEach(Array(data.limits.enumerated()), id: \.offset) { index, limit in
                limitRow(limit)

                if index < data.limits.count - 1 {
                    Rectangle().fill(line.opacity(0.5)).frame(height: 0.5)
                }
            }
        }
    }

    private func limitRow(_ limit: ShareCardData.Limit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(cream.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.3)

                Spacer()

                Text("\(Int(limit.percent * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(metricColor(limit.percent))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(barBg)
                    if limit.percent > 1.0 {
                        OverflowStripes(tint: metricColor(limit.percent))
                    } else {
                        Rectangle()
                            .fill(metricColor(limit.percent))
                            .frame(width: max(0, geo.size.width * CGFloat(limit.percent)))
                    }
                }
            }
            .frame(height: 3)

            if !limit.resetDescription.isEmpty {
                Text(limit.resetDescription)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(secondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Pacing

    private var pacing: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
            Text("Unsustainable pace")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(orange.opacity(0.08))
        .overlay(
            Rectangle()
                .strokeBorder(orange.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("claudephobia")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(terracotta.opacity(0.5))
                Text(formattedTimestamp)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(secondary.opacity(0.4))
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private var worstLimitLabel: String {
        guard let worst = data.limits.max(by: { $0.percent < $1.percent }) else { return "" }
        return worst.label
    }

    private var statusLabel: String {
        if worstPercent >= 0.9 { return "Critical" }
        if worstPercent >= 0.7 { return "Warning" }
        return "Active"
    }

    private var statusColor: Color {
        if worstPercent >= 0.9 { return red }
        if worstPercent >= 0.7 { return orange }
        return terracotta
    }

    private var heroColor: Color {
        if worstPercent >= 0.9 { return red }
        if worstPercent >= 0.7 { return orange }
        return terracotta
    }

    private func metricColor(_ percent: Double) -> Color {
        if percent >= 0.9 { return red }
        if percent >= 0.7 { return orange }
        return terracotta
    }

    private func tierName(_ tier: String) -> String {
        let lower = tier.lowercased()
        if lower.contains("max_20x") || lower.contains("max20x") { return "Claude Max 20x" }
        if lower.contains("max_5x") || lower.contains("max5x") { return "Claude Max 5x" }
        if lower.contains("max") { return "Claude Max" }
        if lower.contains("pro") { return "Claude Pro" }
        if lower.contains("team") { return "Claude Team" }
        if lower.contains("enterprise") { return "Claude Enterprise" }
        if lower.contains("free") || lower.contains("default") { return "Claude Free" }
        return tier.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy  HH:mm"
        return f.string(from: data.timestamp)
    }
}

// MARK: - Renderer

enum ShareCardRenderer {

    static func renderImage(from viewModel: UsageViewModel) -> NSImage? {
        let data = buildCardData(from: viewModel)
        return renderCardImage(data: data)
    }

    static func renderCardImage(data: ShareCardData) -> NSImage? {
        let view = ShareCardView(data: data)
        let hostingView = NSHostingView(rootView: view)

        let fittingSize = hostingView.fittingSize
        let size = NSSize(
            width: max(fittingSize.width, 440),
            height: max(fittingSize.height, 200)
        )

        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    static func share(from viewModel: UsageViewModel, relativeTo positioningView: NSView) {
        guard let image = renderImage(from: viewModel) else { return }
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)
    }

    static func copyToClipboard(from viewModel: UsageViewModel) -> Bool {
        guard let image = renderImage(from: viewModel) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        return true
    }

    static func saveToFile(from viewModel: UsageViewModel) {
        guard let image = renderImage(from: viewModel),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "claude-usage-\(dateStamp()).png"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            try? pngData.write(to: url)
        }
    }

    // MARK: - Private

    private static func buildCardData(from vm: UsageViewModel) -> ShareCardData {
        var limits: [ShareCardData.Limit] = []

        limits.append(.init(
            label: "5-Hour Session",
            percent: vm.sessionPercent,
            resetDescription: vm.sessionResetDescription
        ))

        limits.append(.init(
            label: "7-Day Weekly",
            percent: vm.weeklyPercent,
            resetDescription: vm.weeklyResetDescription
        ))

        if let opus = vm.opusPercent {
            limits.append(.init(
                label: "Weekly \u{2014} Opus",
                percent: opus,
                resetDescription: vm.opusResetDescription ?? ""
            ))
        }

        if let sonnet = vm.sonnetPercent {
            limits.append(.init(
                label: "Weekly \u{2014} Sonnet",
                percent: sonnet,
                resetDescription: vm.sonnetResetDescription ?? ""
            ))
        }

        if let extra = vm.extraUsagePercent {
            limits.append(.init(
                label: "Extra Usage",
                percent: extra,
                resetDescription: vm.extraUsageResetDescription ?? ""
            ))
        }

        return ShareCardData(
            limits: limits,
            tier: vm.rateLimitTier,
            isPacing: vm.isPacingWarning,
            timestamp: vm.lastUpdated ?? Date()
        )
    }

    private static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
