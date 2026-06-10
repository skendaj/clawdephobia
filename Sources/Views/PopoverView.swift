import SwiftUI

extension Bundle {
    /// Safe accessor for SPM resource bundle — returns nil instead of fatalError
    static var safeModule: Bundle? = {
        let bundleName = "Clawdephobia_Clawdephobia"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
        ]
        for candidate in candidates {
            guard let dir = candidate else { continue }
            if let bundle = Bundle(url: dir.appendingPathComponent(bundleName + ".bundle")) {
                return bundle
            }
        }
        return nil
    }()
}

extension Color {
    static let accent = Color(red: 0xDE / 255.0, green: 0x73 / 255.0, blue: 0x56 / 255.0)
}

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var accountStore: AccountStore

    @State private var showAddSheet: Bool = false
    @State private var showRemoveConfirm: Bool = false
    @State private var showInactive: Bool = false
    @State private var terminalSwitchNote: String? = nil

    /// A flattened, render-ready row for the popover usage list. Built fresh each
    /// pass so we partition into active/idle without keeping any extra view-model state.
    private struct UsageItem: Identifiable {
        let id: String
        let title: String
        let percent: Double
        let resetDescription: String
        let tint: Color
    }

    var body: some View {
        Group {
            if viewModel.isSetupComplete {
                usageView
            } else {
                FirstRunSetupView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAccountSheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
    }

    // MARK: - Usage View

    private var usageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)

            terminalSwitchBanner
            failoverPromptBanner

            if viewModel.isUnauthorized {
                expiredBanner
                // Only show cached rows if we actually have a previous snapshot to show
                if viewModel.lastUpdated != nil {
                    Divider().padding(.vertical, 6)
                    if viewModel.isEnterprise {
                        creditsRow.opacity(0.6)
                    } else {
                        renderItems.opacity(0.6)
                    }
                }
            } else if viewModel.isEnterprise {
                creditsRow
            } else {
                renderItems
            }

            Divider().padding(.vertical, 6)

            if let version = viewModel.updateAvailableVersion {
                updateBanner(version: version)
            }

            if viewModel.isServiceDown {
                serviceDownBanner
            }

            if let error = viewModel.errorMessage, !viewModel.isServiceDown, !viewModel.isUnauthorized {
                errorBanner(error)
            }

            footer
        }
        .padding(16)
        .frame(width: 320)
        .alert("Remove this account?", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                viewModel.removeActiveAccount()
            }
        } message: {
            Text("\(accountStore.activeAccount?.label ?? "This account") will be removed from Clawdephobia. Its session key is deleted from Keychain.")
        }
    }

    // MARK: - Header (with switcher)

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIconView(size: 18)
            accountSwitcher
            if let plan = viewModel.planDisplayName {
                planBadge(plan)
            }
            terminalStatusGlyph
            Spacer()
            Button(action: { viewModel.showSettingsWindow = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Clawdephobia")
        }
    }

    private var accountSwitcher: some View {
        Menu {
            // Each account row — click to set active
            ForEach(accountStore.accounts) { account in
                Button {
                    switchAccount(to: account.id)
                } label: {
                    HStack {
                        if account.id == accountStore.activeId {
                            Image(systemName: "checkmark")
                        }
                        Text(switcherRowLabel(for: account))
                    }
                }
            }

            if !accountStore.accounts.isEmpty {
                Divider()
            }

            Button("Add account\u{2026}") {
                showAddSheet = true
            }

            Button("Manage accounts\u{2026}") {
                viewModel.showSettingsWindow = true
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayLabel(accountStore.activeAccount?.label) ?? "Clawdephobia")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .layoutPriority(0)
        .help(accountStore.activeAccount?.label ?? "")
    }

    /// Terminal-link status indicator in the header — green when switching accounts will
    /// re-point the `claude` CLI for the active account, grey when it still needs setup.
    /// Mirrors the menu-bar status dot. Hidden when the sync feature is off/unsupported.
    @ViewBuilder
    private var terminalStatusGlyph: some View {
        switch accountStore.terminalSyncState {
        case .off:
            EmptyView()
        case .connected, .needsSetup:
            let connected = accountStore.terminalSyncState == .connected
            Button(action: { viewModel.showSettingsWindow = true }) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(connected ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(connected
                  ? "Terminal sync on — switching accounts re-points `claude` to this account"
                  : "Terminal sync on, but this account isn't linked yet. Run `claude login`, then capture it in Settings → Accounts.")
        }
    }

    /// Switches the active account and, when terminal sync is on, surfaces a transient
    /// note if a `claude` session is running (it won't pick up the swap until restarted).
    private func switchAccount(to id: String) {
        guard id != accountStore.activeId else { return }
        viewModel.setActiveAccount(id)
        guard accountStore.syncTerminalLoginEnabled,
              ClaudeCodeCredentialBridge.isSupported,
              accountStore.terminalLoginLinked(for: id) else { return }
        if accountStore.isClaudeRunning() {
            terminalSwitchNote = "Terminal switched. Start a new `claude` session to use this account — running sessions keep the old login."
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                terminalSwitchNote = nil
            }
        }
    }

    /// Confirm-mode failover prompt: appears when the active account is nearly out and
    /// the user opted to be asked before switching. Mirrors the auto-jump notification.
    @ViewBuilder
    private var failoverPromptBanner: some View {
        if let p = viewModel.pendingFailover {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.accent)
                    Text("\(p.fromLabel) is at \(p.fromPercent)%. Switch to \(p.toLabel)?")
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Button("Switch to \(p.toLabel)") { viewModel.acceptFailover() }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                    Button("Not now") { viewModel.dismissFailover() }
                        .controlSize(.small)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accent.opacity(0.08))
            .cornerRadius(6)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var terminalSwitchBanner: some View {
        if let note = terminalSwitchNote {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundColor(.accent)
                Text(note)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accent.opacity(0.08))
            .cornerRadius(6)
            .padding(.bottom, 6)
        }
    }

    /// Trims overly verbose org labels like `"someone@example.com's Organization"`
    /// down to something that fits in the menu bar header. Storage is untouched.
    private func displayLabel(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        var trimmed = raw
        let orgSuffix = "\u{2019}s Organization"  // typographic apostrophe
        let asciiSuffix = "'s Organization"
        for suffix in [orgSuffix, asciiSuffix] {
            if trimmed.hasSuffix(suffix) {
                trimmed = String(trimmed.dropLast(suffix.count))
                break
            }
        }
        if let at = trimmed.firstIndex(of: "@") {
            trimmed = String(trimmed[..<at])
        }
        return trimmed.isEmpty ? raw : trimmed
    }

    private func switcherRowLabel(for account: Account) -> String {
        if account.id == accountStore.activeId {
            return "\(account.label)  \u{2022}  \(Int(viewModel.sessionPercent * 100))% / \(Int(viewModel.weeklyPercent * 100))%"
        }
        if let peek = accountStore.peeks[account.id] {
            return "\(account.label)  \u{2022}  \(Int(peek.sessionPercent * 100))% / \(Int(peek.weeklyPercent * 100))%"
        }
        return account.label
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            if let updated = viewModel.lastUpdated {
                Text(timeAgo(updated))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
                    .lineLimit(1)
            }
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 16, height: 12)
                .padding(.leading, 6)
                .opacity(viewModel.isLoading ? 1 : 0)
            // Version label hidden in popover footer (still shown in Settings → About).
            // if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty {
            //     Text("v\(version)")
            //         .font(.system(size: 11))
            //         .foregroundColor(.secondary)
            //         .lineLimit(1)
            // }
            Spacer(minLength: 8)

            Button(action: { showRemoveConfirm = true }) {
                Label("Remove", systemImage: "person.fill.xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Remove this account from Clawdephobia")

            Spacer().frame(width: 12)

            Button(action: { viewModel.fetchUsage() }) {
                Label(viewModel.isLoading ? "Refreshing\u{2026}" : "Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(viewModel.isLoading)
            .help("Refresh")
        }
    }

    // MARK: - Banners

    private func updateBanner(version: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(version) available")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                Button("Download \u{2192}") {
                    if let url = URL(string: viewModel.updateReleaseURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.blue.opacity(0.8))
            }
            Spacer()
            Button("Dismiss") {
                viewModel.dismissUpdate()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(6)
        .padding(.bottom, 8)
    }

    private var expiredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.slash")
                .foregroundColor(.orange)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("Session expired")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                Text("Sign in to claude.ai, then paste a new key.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showAddSheet = true }) {
                Text("Update \u{2192}")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(6)
        .padding(.bottom, 8)
    }

    private var serviceDownBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "icloud.slash.fill")
                .foregroundColor(.red)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("Clawd service appears down")
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

    private func errorBanner(_ error: String) -> some View {
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

    // MARK: - Items list (active + idle accordion)

    private var allItems: [UsageItem] {
        var items: [UsageItem] = []
        items.append(UsageItem(
            id: "5h",
            title: "5-hour session",
            percent: viewModel.sessionPercent,
            resetDescription: viewModel.sessionResetDescription,
            tint: barColor(viewModel.sessionPercent)
        ))
        items.append(UsageItem(
            id: "7d",
            title: "7-day weekly",
            percent: viewModel.weeklyPercent,
            resetDescription: viewModel.weeklyResetDescription,
            tint: barColor(viewModel.weeklyPercent)
        ))
        if let p = viewModel.opusPercent {
            items.append(UsageItem(id: "opus", title: "Weekly \u{2014} Opus", percent: p,
                resetDescription: viewModel.opusResetDescription ?? "", tint: barColor(p)))
        }
        if let p = viewModel.sonnetPercent {
            items.append(UsageItem(id: "sonnet", title: "Weekly \u{2014} Sonnet", percent: p,
                resetDescription: viewModel.sonnetResetDescription ?? "", tint: barColor(p)))
        }
        if let p = viewModel.oauthAppsPercent {
            items.append(UsageItem(id: "oauth", title: "Weekly \u{2014} OAuth Apps", percent: p,
                resetDescription: viewModel.oauthAppsResetDescription ?? "", tint: barColor(p)))
        }
        if let p = viewModel.coworkPercent {
            items.append(UsageItem(id: "cowork", title: "Weekly \u{2014} Cowork", percent: p,
                resetDescription: viewModel.coworkResetDescription ?? "", tint: barColor(p)))
        }
        // Personal accounts with extra_usage enabled — render as a regular row
        // (active when percent > 0, falls into the inactive accordion otherwise).
        let extraPercentFromCents: Double? = {
            guard let used = viewModel.spendLimitUsedCents ?? viewModel.extraCreditsUsed,
                  let limit = viewModel.spendLimitMonthlyCents ?? viewModel.extraCreditsMonthlyLimit,
                  limit > 0 else { return nil }
            return min(1.0, used / limit)
        }()
        let extraPercent = extraPercentFromCents ?? viewModel.extraUsagePercent
        if viewModel.extraCreditsEnabled
            || viewModel.spendLimitMonthlyCents != nil
            || (viewModel.extraCreditsUsed ?? 0) > 0
            || extraPercent != nil {
            items.append(UsageItem(
                id: "extra",
                title: "Extra usage",
                percent: extraPercent ?? 0,
                resetDescription: extraUsageSubtitle(),
                tint: .purple
            ))
        }
        items.append(UsageItem(
            id: "design",
            title: "Claude Design",
            percent: viewModel.omelettePercent ?? 0,
            resetDescription: viewModel.omeletteResetDescription ?? "",
            tint: .orange
        ))
        if let p = viewModel.promotionalOmelettePercent {
            items.append(UsageItem(id: "promo", title: "Promotional", percent: p,
                resetDescription: viewModel.promotionalOmeletteResetDescription ?? "", tint: .pink))
        }
        return items
    }

    @ViewBuilder
    private var renderItems: some View {
        let items = allItems
        let active = items.filter { $0.percent > 0 }
        let idle = items.filter { $0.percent <= 0 }
        let expanded = showInactive || active.isEmpty

        // Active section
        ForEach(Array(active.enumerated()), id: \.element.id) { index, item in
            if index > 0 { Divider().padding(.vertical, 6) }
            usageRow(
                title: item.title,
                percent: item.percent,
                resetDescription: item.resetDescription,
                tint: item.tint
            )
        }

        // Idle accordion — full-width clickable header (chevron + label both tap-targets)
        if !idle.isEmpty {
            if !active.isEmpty { Divider().padding(.vertical, 6) }
            Button(action: {
                guard !active.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.18)) { showInactive.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text("Inactive limits \u{00B7} \(idle.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(idle.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.vertical, 6) }
                        usageRow(
                            title: item.title,
                            percent: item.percent,
                            resetDescription: item.resetDescription,
                            tint: item.tint
                        )
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Credits Row (pay-as-you-go / enterprise)

    private var creditsRow: some View {
        // API reports amounts in cents (`1437.0` ⇒ `$14.37`).
        let currency = viewModel.extraCreditsCurrency ?? "USD"
        let usedDollars = (viewModel.extraCreditsUsed ?? 0) / 100.0
        let limitDollars: Double? = viewModel.extraCreditsMonthlyLimit.map { $0 / 100.0 }
        let usedString = formatCurrency(usedDollars, code: currency)
        let pct: Double? = {
            guard let limit = limitDollars, limit > 0 else { return nil }
            return min(1.0, usedDollars / limit)
        }()
        let resetSubtitle = viewModel.creditsResetDescription

        let badgeText = limitDollars == nil ? "Unlimited" : "Capped"

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(viewModel.planDisplayName ?? "Enterprise")
                    .font(.system(size: 13, weight: .medium))
                Text(badgeText)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(3)
                Spacer()
                Text(usedString)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.purple)
            }
            HStack {
                Text(resetSubtitle.isEmpty ? " " : resetSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Spent")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            if let pct = pct, let limit = limitDollars {
                if viewModel.viewProgressStyle == 1 {
                    HStack(alignment: .center, spacing: 12) {
                        Text("\(usedString) of \(formatCurrency(limit, code: currency))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        UsageCircularProgress(value: pct, tint: barColor(pct), size: 48)
                    }
                    .padding(.top, 2)
                } else {
                    UsageProgressBar(value: pct, tint: barColor(pct))
                        .frame(height: 6)
                        .padding(.top, 2)
                    Text("\(usedString) of \(formatCurrency(limit, code: currency))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Plan Badge (header)

    @ViewBuilder
    private func planBadge(_ name: String) -> some View {
        let isPremium = (name == "Enterprise" || name == "Team" || name.hasPrefix("Max"))
        let tint: Color = isPremium ? .purple : .secondary
        let bg: Color = isPremium ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.15)
        Text(name.uppercased())
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(bg)
            .foregroundColor(tint)
            .cornerRadius(3)
    }

    // MARK: - Extra Usage Subtitle (inline on the limit row)

    /// Builds the compact dollar subtitle for the "Extra usage" row, e.g.
    /// "$0.29 of $35 · Bal $1.83 · Resets Jun 1". Each segment is skipped
    /// when its source value is missing.
    private func extraUsageSubtitle() -> String {
        let currency = viewModel.spendLimitCurrency
            ?? viewModel.extraCreditsCurrency
            ?? viewModel.prepaidCurrency
            ?? "USD"
        let spentCents = viewModel.spendLimitUsedCents ?? viewModel.extraCreditsUsed
        let limitCents = viewModel.spendLimitMonthlyCents ?? viewModel.extraCreditsMonthlyLimit
        let balanceCents = viewModel.prepaidBalanceCents

        var parts: [String] = []
        if let spentCents = spentCents {
            let spent = spentCents / 100.0
            if let limitCents = limitCents {
                parts.append("\(formatCurrency(spent, code: currency)) of \(formatCurrency(limitCents / 100.0, code: currency))")
            } else {
                parts.append("\(formatCurrency(spent, code: currency)) spent")
            }
        } else if let limitCents = limitCents {
            parts.append("Limit \(formatCurrency(limitCents / 100.0, code: currency))")
        }
        if let balanceCents = balanceCents {
            parts.append("Balance \(formatCurrency(balanceCents / 100.0, code: currency))")
        }
        let reset = viewModel.creditsResetDescription
        if !reset.isEmpty { parts.append(reset) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func formatCurrency(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(code)"
    }

    // MARK: - Usage Row

    private func usageRow(title: String, percent: Double, resetDescription: String, tint: Color) -> some View {
        Group {
            if viewModel.viewProgressStyle == 1 {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                        if !resetDescription.isEmpty {
                            Text(resetDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    UsageCircularProgress(value: percent, tint: tint, size: 48)
                }
                .padding(.vertical, 6)
            } else {
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
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private func barColor(_ percent: Double) -> Color {
        if percent >= 0.9 { return .red }
        if percent >= 0.7 { return .orange }
        return .blue
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

// MARK: - First-run setup

private struct FirstRunSetupView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var sessionKey: String = ""
    @State private var isTesting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button(action: { viewModel.closePopoverRequested = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            AppIconView(size: 48)

            Text("Clawdephobia")
                .font(.headline)

            Text("Fear of hitting Clawd limits")
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
                Text("1. Sign in to your account in a browser")
                Text("2. DevTools (Cmd+Opt+I) \u{2192} Application \u{2192} Cookies")
                Text("3. Copy the sessionKey value")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text("Stay signed in to claude.ai or the session key expires.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("No cost. Uses your existing session cookie.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty {
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }

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
            .tint(Color.accent)
            .disabled(sessionKey.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)

            HStack(spacing: 6) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.2))
                Text("or")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.2))
            }

            Button("Try Demo Mode") {
                _ = viewModel.enableDemoAccount()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func connect() {
        let key = sessionKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        isTesting = true
        errorMessage = nil
        let pending = key
        sessionKey = ""

        Task { @MainActor in
            do {
                _ = try await viewModel.addAccount(sessionKey: pending)
            } catch {
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
    @ObservedObject var viewModel: UsageViewModel
    var onDismiss: () -> Void

    @State private var sessionKey: String = ""
    @State private var isTesting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add account")
                .font(.headline)

            Text("Paste a session key from another Claude account. Clawdephobia will detect the account name automatically — you can rename it later.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("sk-ant-sid01-...", text: $sessionKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text("Stay signed in to claude.ai on this browser for every account you add. If you sign out, the session key expires and you'll need to paste a fresh one.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(3)
            }

            HStack {
                Spacer()
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)
                Button(action: submit) {
                    ZStack {
                        Text("Add").opacity(isTesting ? 0 : 1)
                        if isTesting {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .disabled(sessionKey.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func submit() {
        let key = sessionKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        isTesting = true
        errorMessage = nil

        Task { @MainActor in
            do {
                _ = try await viewModel.addAccount(sessionKey: key)
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

// MARK: - Progress Bar

struct AppIconView: View {
    var size: CGFloat = 48

    private static let cachedImage: NSImage = {
        if let spm = Bundle.safeModule?.url(forResource: "icon", withExtension: "png"),
           let image = NSImage(contentsOf: spm) {
            image.size = NSSize(width: 256, height: 256)
            return image
        }
        if let app = Bundle.main.url(forResource: "icon", withExtension: "png"),
           let image = NSImage(contentsOf: app) {
            image.size = NSSize(width: 256, height: 256)
            return image
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }()

    var body: some View {
        Image(nsImage: Self.cachedImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
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

// MARK: - Circular Progress

struct UsageCircularProgress: View {
    let value: Double
    var tint: Color = .blue
    var size: CGFloat = 38

    private var isOverflow: Bool { value > 1.0 }
    private var safeValue: Double { value.isFinite ? min(value, 1.0) : 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 4)

            Circle()
                .trim(from: 0, to: CGFloat(safeValue))
                .stroke(
                    isOverflow ? AnyShapeStyle(tint.opacity(0.7)) : AnyShapeStyle(tint),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: safeValue)

            if isOverflow {
                Image(systemName: "exclamationmark")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundColor(tint)
            } else {
                Text("\(Int(value * 100))%")
                    .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
            }
        }
        .frame(width: size, height: size)
    }
}
