import AppKit

enum MenuBarRenderer {

    private static let iconWidth: CGFloat = 80

    static func createImage(sessionPercent: Double, weeklyPercent: Double,
                            isPacingWarning: Bool, isServiceDown: Bool = false,
                            menuBarProgressStyle: Int = 0) -> NSImage {
        let height: CGFloat = 16

        let flameImg: NSImage? = isPacingWarning ? createFlameImage() : nil
        let downImg: NSImage? = isServiceDown ? createServiceDownImage() : nil
        let trailingImg = downImg ?? flameImg
        let trailingSpace: CGFloat = trailingImg.map { $0.size.width + 2 } ?? 0

        let baseWidth: CGFloat = menuBarProgressStyle == 1 ? circleIconWidth(session: sessionPercent, weekly: weeklyPercent) : iconWidth
        let totalWidth = baseWidth + trailingSpace

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()

        if menuBarProgressStyle == 1 {
            drawDualCirclePaired(session: sessionPercent, weekly: weeklyPercent, height: height,
                                 isServiceDown: isServiceDown)
        } else {
            drawDualBar(session: sessionPercent, weekly: weeklyPercent, width: iconWidth, height: height,
                        isServiceDown: isServiceDown)
        }

        if let trailing = trailingImg {
            let y = (height - trailing.size.height) / 2
            trailing.draw(at: NSPoint(x: baseWidth + 2, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func titleText(sessionPercent: Double, weeklyPercent: Double, displayMode: Int,
                          menuBarProgressStyle: Int = 0) -> String {
        // Circles mode embeds values in the icon image — no separate title text needed
        if menuBarProgressStyle == 1 { return "" }
        switch displayMode {
        case 1:  return " \(pct(sessionPercent)) \u{00B7} \(pct(weeklyPercent))"
        case 2:  return " \(pct(sessionPercent))/\(pct(weeklyPercent))"
        default: return ""
        }
    }

    static func tooltip(sessionPercent: Double, sessionReset: String,
                        weeklyPercent: Double, weeklyReset: String,
                        isServiceDown: Bool = false) -> String {
        var lines: [String] = []
        if isServiceDown {
            lines.append("Claude service appears down")
            lines.append("")
        }
        lines.append("5-hour session: \(pct(sessionPercent)) used")
        if !sessionReset.isEmpty { lines.append(sessionReset) }
        lines.append("7-day weekly: \(pct(weeklyPercent)) used")
        if !weeklyReset.isEmpty { lines.append(weeklyReset) }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func pct(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private static func gaugeColor(for percent: Double) -> NSColor {
        if percent >= 0.9 { return .systemRed }
        if percent >= 0.7 { return .systemOrange }
        return .systemGreen
    }

    private static func barColor(for percent: Double) -> NSColor {
        if percent >= 0.9 { return .systemRed }
        if percent >= 0.7 { return .systemOrange }
        return .systemBlue
    }

    // MARK: - Service Down

    private static func createServiceDownImage() -> NSImage? {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        let config = sizeConfig.applying(colorConfig)

        if let symbol = NSImage(systemSymbolName: "icloud.slash.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            return symbol
        }
        let size = NSSize(width: 8, height: 8)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        return img
    }

    // MARK: - Flame

    private static func createFlameImage() -> NSImage? {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
        let config = sizeConfig.applying(colorConfig)

        if let symbol = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            return symbol
        }
        let size = NSSize(width: 6, height: 8)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        return img
    }

    // MARK: - Dual Circle (paired with value text)

    /// Returns the width needed to fit two circle+value pairs.
    private static func circleIconWidth(session: Double, weekly: Double) -> CGFloat {
        let circleD: CGFloat = 12
        let textGap: CGFloat = 3
        let pairGap: CGFloat = 6
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let sessionW = (pct(session) as NSString).size(withAttributes: attrs).width
        let weeklyW  = (pct(weekly)  as NSString).size(withAttributes: attrs).width
        return ceil(circleD + textGap + sessionW + pairGap + circleD + textGap + weeklyW + 2)
    }

    /// Draws two circle+value pairs: [○ 26%] [○ 56%]
    private static func drawDualCirclePaired(session: Double, weekly: Double, height: CGFloat,
                                             isServiceDown: Bool = false) {
        let circleD: CGFloat = 12
        let textGap: CGFloat = 3
        let pairGap: CGFloat = 6
        let alpha: CGFloat = isServiceDown ? 0.4 : 1.0
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

        // Session pair
        let circleY = (height - circleD) / 2
        drawCircleArc(in: NSRect(x: 1, y: circleY, width: circleD, height: circleD),
                      percent: session, alpha: alpha)
        let sessionLabel = pct(session)
        let sessionLabelSize = (sessionLabel as NSString).size(withAttributes: [.font: font])
        let sessionTextX = 1 + circleD + textGap
        let sessionTextY = (height - sessionLabelSize.height) / 2
        let sessionColor = barColor(for: session).withAlphaComponent(alpha)
        (sessionLabel as NSString).draw(
            at: NSPoint(x: sessionTextX, y: sessionTextY),
            withAttributes: [.font: font, .foregroundColor: sessionColor]
        )

        // Weekly pair
        let weeklyCircleX = sessionTextX + sessionLabelSize.width + pairGap
        drawCircleArc(in: NSRect(x: weeklyCircleX, y: circleY, width: circleD, height: circleD),
                      percent: weekly, alpha: alpha)
        let weeklyLabel = pct(weekly)
        let weeklyLabelSize = (weeklyLabel as NSString).size(withAttributes: [.font: font])
        let weeklyTextX = weeklyCircleX + circleD + textGap
        let weeklyTextY = (height - weeklyLabelSize.height) / 2
        let weeklyColor = barColor(for: weekly).withAlphaComponent(alpha)
        (weeklyLabel as NSString).draw(
            at: NSPoint(x: weeklyTextX, y: weeklyTextY),
            withAttributes: [.font: font, .foregroundColor: weeklyColor]
        )
    }

    private static func drawCircleArc(in rect: NSRect, percent: Double, alpha: CGFloat = 1.0) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let lineWidth: CGFloat = 2.0
        let radius = rect.width / 2 - lineWidth / 2

        // Background ring
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.25).setStroke()
        bgPath.lineWidth = lineWidth
        bgPath.stroke()

        // Filled arc — clockwise from top (90°)
        let safePercent = min(max(percent, 0), 1.0)
        if safePercent > 0 {
            let startAngle: CGFloat = 90
            let endAngle: CGFloat = 90 - CGFloat(safePercent * 360)
            let fillPath = NSBezierPath()
            fillPath.appendArc(withCenter: center, radius: radius,
                               startAngle: startAngle, endAngle: endAngle, clockwise: true)
            barColor(for: percent).withAlphaComponent(alpha).setStroke()
            fillPath.lineWidth = lineWidth
            fillPath.lineCapStyle = .round
            fillPath.stroke()
        }
    }

    // MARK: - Dual Bar

    private static func drawDualBar(session: Double, weekly: Double, width: CGFloat, height: CGFloat,
                                    isServiceDown: Bool = false) {
        let dotSize: CGFloat = 7
        let dotGap: CGFloat = 4
        let barWidth = width - dotSize - dotGap
        let barHeight: CGFloat = 5
        let gap: CGFloat = 2
        let topY = (height + gap) / 2
        let botY = (height - gap) / 2 - barHeight
        let barX = dotSize + dotGap

        // Status dot — grey when service is down
        let worst = max(session, weekly)
        let dotY = (height - dotSize) / 2
        let dotPath = NSBezierPath(ovalIn: NSRect(x: 0, y: dotY, width: dotSize, height: dotSize))
        let dotColor: NSColor = isServiceDown ? .systemGray : gaugeColor(for: worst)
        dotColor.setFill()
        dotPath.fill()

        // Bars — dimmed when service is down
        let alpha: CGFloat = isServiceDown ? 0.4 : 1.0
        drawPillBar(in: NSRect(x: barX, y: topY, width: barWidth, height: barHeight), percent: session, alpha: alpha)
        drawPillBar(in: NSRect(x: barX, y: botY, width: barWidth, height: barHeight), percent: weekly, alpha: alpha)
    }

    private static func drawPillBar(in rect: NSRect, percent: Double, alpha: CGFloat = 1.0) {
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.25).setFill()
        bgPath.fill()

        let inset: CGFloat = 0.5
        let maxW = rect.width - inset * 2
        let fillW = max(0, min(maxW, maxW * CGFloat(percent)))
        if fillW > 0 {
            let fillRect = NSRect(x: rect.minX + inset, y: rect.minY + inset,
                                  width: fillW, height: rect.height - inset * 2)
            let fillPath = NSBezierPath(roundedRect: fillRect,
                                        xRadius: fillRect.height / 2, yRadius: fillRect.height / 2)
            barColor(for: percent).withAlphaComponent(alpha).setFill()
            fillPath.fill()
        }
    }
}
