import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case notifications = "Notifications"
    case phone = "Phone"
    case account = "Accounts"
    case data = "Data"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .phone: return "iphone"
        case .account: return "person.2"
        case .data: return "externaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var accountStore: AccountStore
    var onClose: () -> Void

    @State private var selectedTab: SettingsTab = .general
    @State private var showResetConfirm = false
    @State private var showAddAccountSheet = false
    @State private var renamingId: String? = nil
    @State private var renameDraft: String = ""
    @State private var removeCandidateId: String? = nil

    @AppStorage(AccountStore.syncTerminalLoginKey) private var syncTerminalLogin = false
    @State private var captureError: String? = nil
    /// Bumped after a capture so rows re-evaluate `terminalLoginLinked` (a Keychain read).
    @State private var terminalLinkRefresh = 0

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                AppIconView(size: 52)

                Text("Fear of hitting Clawd limits")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                ForEach(SettingsTab.allCases) { tab in
                    sidebarButton(tab)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 160)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedTab.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.bottom, 16)

                ScrollView {
                    tabContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 8)

                HStack {
                    Spacer()
                    Button("Done") { onClose() }
                        .keyboardShortcut(.escape)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 540, height: 680)
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                viewModel.resetAllData()
                onClose()
            }
        } message: {
            Text("This deletes all Clawdephobia data including every account's session key from Keychain and removes the login item.")
        }
        .alert("Remove account?", isPresented: Binding(
            get: { removeCandidateId != nil },
            set: { if !$0 { removeCandidateId = nil } }
        )) {
            Button("Cancel", role: .cancel) { removeCandidateId = nil }
            Button("Remove", role: .destructive) {
                if let id = removeCandidateId {
                    accountStore.remove(id: id)
                }
                removeCandidateId = nil
            }
        } message: {
            let label = removeCandidateId.flatMap { accountStore.account(for: $0)?.label } ?? "this account"
            Text("\(label) will be removed and its session key deleted from Keychain.")
        }
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountSheet(viewModel: viewModel) {
                showAddAccountSheet = false
            }
        }
    }

    // MARK: - Sidebar Button

    private func sidebarButton(_ tab: SettingsTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .frame(width: 18)
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                Text(tab.rawValue)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .notifications:
            notificationsTab
        case .phone:
            phoneTab
        case .account:
            accountTab
        case .data:
            dataTab
        case .about:
            aboutTab
        }
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Text display")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Display", selection: Binding(
                    get: { viewModel.menuBarDisplayMode },
                    set: { viewModel.setMenuBarDisplayMode($0) }
                )) {
                    Text("Icon only").tag(0)
                    Text("Icon + percentages").tag(1)
                    Text("Icon + compact").tag(2)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Progress style")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Menu bar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Menu bar", selection: Binding(
                            get: { viewModel.menuBarProgressStyle },
                            set: { viewModel.setMenuBarProgressStyle($0) }
                        )) {
                            Text("Bars").tag(0)
                            Text("Circles").tag(1)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Content view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Content view", selection: Binding(
                            get: { viewModel.viewProgressStyle },
                            set: { viewModel.setViewProgressStyle($0) }
                        )) {
                            Text("Bars").tag(0)
                            Text("Circles").tag(1)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Auto-refresh interval")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Interval", selection: Binding(
                    get: { viewModel.refreshInterval },
                    set: { viewModel.setRefreshInterval($0) }
                )) {
                    Text("Every 1 minute").tag(60)
                    Text("Every 5 minutes").tag(300)
                    Text("Every 10 minutes").tag(600)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { _ in viewModel.toggleLaunchAtLogin() }
                ))

                Text("Start Clawdephobia automatically when you log in")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button("Quit Clawdephobia") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)

                Text("Close the app completely. It will not monitor usage until reopened.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .tint(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))
    }

    // MARK: - Notifications

    private var notificationsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            Toggle("Enable notifications", isOn: Binding(
                get: { viewModel.notificationsEnabled },
                set: { _ in viewModel.toggleNotifications() }
            ))

            if viewModel.notificationsEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Thresholds")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .frame(width: 16)
                            Text("Warning at")
                                .frame(width: 70, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { viewModel.warningThreshold },
                                set: { viewModel.setWarningThreshold($0) }
                            )) {
                                Text("75%").tag(0.75)
                                Text("80%").tag(0.80)
                                Text("90%").tag(0.90)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 170)
                            Spacer()
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "flame")
                                .foregroundColor(.red)
                                .frame(width: 16)
                            Text("Critical at")
                                .frame(width: 70, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { viewModel.criticalThreshold },
                                set: { viewModel.setCriticalThreshold($0) }
                            )) {
                                Text("90%").tag(0.90)
                                Text("95%").tag(0.95)
                                Text("100%").tag(1.00)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 170)
                            Spacer()
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Notify when limits reset", isOn: Binding(
                        get: { viewModel.notifyOnReset },
                        set: { _ in viewModel.toggleNotifyOnReset() }
                    ))

                    Text("Get notified when a rate limit window resets and your usage is restored.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Monitored limits")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("5-hour session", systemImage: "clock")
                        Label("7-day weekly", systemImage: "calendar")
                        Label("Opus weekly (when available)", systemImage: "sparkles")
                        Label("Sonnet weekly (when available)", systemImage: "sparkles")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Button("Send Test Notification") {
                        viewModel.sendTestNotification()
                    }

                    Text("Notifications are sent via native macOS alerts. No permission required.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            }
        }
        .tint(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))
    }

    // MARK: - Phone

    private var phoneTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Get Clawdephobia alerts on your phone via ntfy.sh \u{2014} a free, open-source push service. Works with iOS and Android.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Enable phone notifications", isOn: Binding(
                get: { viewModel.pushNotificationsEnabled },
                set: { _ in viewModel.togglePushNotifications() }
            ))

            if viewModel.pushNotificationsEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Setup")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Install the ntfy app (App Store or Google Play)", systemImage: "1.circle")
                        Label("Subscribe to a unique topic (e.g. clawdephobia-yourname)", systemImage: "2.circle")
                        Label("Enter that same topic below", systemImage: "3.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Topic")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("e.g. clawdephobia-yourname123", text: Binding(
                        get: { viewModel.pushTopic },
                        set: { viewModel.setPushTopic($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    Text("Use a unique, hard-to-guess name \u{2014} ntfy topics are public by default.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Server URL")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("https://ntfy.sh", text: Binding(
                        get: { viewModel.pushServerURL },
                        set: { viewModel.setPushServerURL($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    Text("Use https://ntfy.sh (default) or your own self-hosted ntfy server.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Button("Send Test to Phone") {
                        viewModel.sendTestPushNotification()
                    }
                    .disabled(viewModel.pushTopic.trimmingCharacters(in: .whitespaces).isEmpty)

                    Text("Critical alerts are sent with urgent priority to break through Do Not Disturb.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))
    }

    // MARK: - Accounts

    private var accountTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Each session key is stored securely in macOS Keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if accountStore.accounts.isEmpty {
                Text("No accounts yet. Add one to start tracking usage.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(accountStore.accounts) { account in
                        accountRow(account)
                        if account.id != accountStore.accounts.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button("Add account\u{2026}") {
                    showAddAccountSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))

                Button("Try Demo Mode") {
                    _ = viewModel.enableDemoAccount()
                }
                .font(.caption)
            }

            Divider()
            terminalSyncSection

            Spacer(minLength: 0)
        }
    }

    /// "Switch the terminal too" controls. The CLI login lives in another app's Keychain
    /// item, which the sandbox forbids — so this whole section only appears in the
    /// direct-download build (see `ClaudeCodeCredentialBridge.isSupported`).
    @ViewBuilder
    private var terminalSyncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Terminal (Claude Code)")
                    .font(.system(size: 12, weight: .semibold))
            }

            if ClaudeCodeCredentialBridge.isSupported {
                Toggle("Switch the terminal login when I change accounts", isOn: $syncTerminalLogin)
                    .font(.caption)
                    .toggleStyle(.checkbox)

                Text("Run `claude login` for an account in Terminal, then click the terminal icon on its row to link it. Switching accounts will then re-point `claude` to that login.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                caveat("Already-open `claude` sessions don't change — only ones you start after switching. Just open a fresh terminal.")
                caveat("Available in the direct-download (DMG) version only — the Mac App Store sandbox doesn't allow touching the CLI's login, so it's hidden there.")

                if let captureError {
                    Text(captureError)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Switching the terminal's `claude` login is only available in the direct-download (DMG) version — the Mac App Store sandbox doesn't allow it.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A muted "good to know" line with a leading info dot, used for the terminal-sync caveats.
    private func caveat(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func captureTerminal(_ id: String) {
        do {
            try accountStore.captureTerminalLogin(for: id)
            captureError = nil
            terminalLinkRefresh += 1
        } catch {
            captureError = error.localizedDescription
        }
    }

    private func accountRow(_ account: Account) -> some View {
        let isActive = account.id == accountStore.activeId
        let session = isActive
            ? viewModel.sessionPercent
            : (accountStore.peeks[account.id]?.sessionPercent ?? 0)
        let weekly = isActive
            ? viewModel.weeklyPercent
            : (accountStore.peeks[account.id]?.weeklyPercent ?? 0)

        return HStack(spacing: 10) {
            Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isActive ? Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0) : .secondary)
                .font(.system(size: 14))
                .onTapGesture {
                    accountStore.setActive(account.id)
                }

            VStack(alignment: .leading, spacing: 2) {
                if renamingId == account.id {
                    HStack(spacing: 6) {
                        TextField("Label", text: $renameDraft, onCommit: { commitRename(account.id) })
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 180)
                        Button("Save") { commitRename(account.id) }
                            .controlSize(.small)
                        Button("Cancel") { renamingId = nil }
                            .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(account.label)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(account.label)
                        if account.isDemo {
                            Text("DEMO")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                        }
                    }
                    if let detected = account.detectedName, detected != account.label {
                        Text(detected)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(detected)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text("\(Int(session * 100))% / \(Int(weekly * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)

            if ClaudeCodeCredentialBridge.isSupported && !account.isDemo {
                let _ = terminalLinkRefresh   // re-evaluate the Keychain read after a capture
                let linked = accountStore.terminalLoginLinked(for: account.id)
                Button(action: { captureTerminal(account.id) }) {
                    Image(systemName: linked ? "terminal.fill" : "terminal")
                        .font(.system(size: 12))
                        .foregroundColor(linked ? Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0) : .secondary)
                }
                .buttonStyle(.plain)
                .help(linked
                      ? "Terminal login linked — click to re-capture the current `claude login`"
                      : "Link this account's terminal login (run `claude login` first)")
            }

            Button(action: { startRename(account) }) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Rename")
            .disabled(renamingId == account.id)

            Button(action: { removeCandidateId = account.id }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func startRename(_ account: Account) {
        renamingId = account.id
        renameDraft = account.label
    }

    private func commitRename(_ id: String) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            accountStore.rename(id, to: trimmed)
        }
        renamingId = nil
        renameDraft = ""
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// GitHub release URL for the displayed version (`v1.0.0` → release tag `v1.0.0`).
    /// Both Mac App Store and GitHub builds ship from the same release tag so the
    /// link works for either install source.
    private func githubReleaseURL(for version: String) -> URL? {
        let trimmed = version.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let tag = trimmed.hasPrefix("v") ? trimmed : "v\(trimmed)"
        return URL(string: "https://github.com/skendaj/Claudephobia/releases/tag/\(tag)")
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Clawdephobia")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !appVersion.isEmpty {
                    if let releaseURL = githubReleaseURL(for: appVersion) {
                        Link("v\(appVersion)", destination: releaseURL)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .help("Open GitHub release notes for v\(appVersion)")
                    } else {
                        Text("v\(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Clawdephobia reads your usage data directly from the Clawd API using your session cookie. No data is sent to any third party. No cost involved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Open source and free forever.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("Built by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("skendaj")
                        .font(.caption)
                        .foregroundColor(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/skendaj") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Found a bug or have a suggestion?")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Contact support")
                    .font(.caption)
                    .foregroundColor(Color(red: 0xDE/255.0, green: 0x73/255.0, blue: 0x56/255.0))
                    .onTapGesture {
                        if let url = URL(string: "mailto:skendajbruno07@gmail.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }
            }
        }
    }

    // MARK: - Data

    private var dataTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Export")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Save current usage data as a JSON file for external tools or dashboards.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Export Usage JSON...") {
                    viewModel.exportToFile()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Reset")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Remove all Clawdephobia data including session key, settings, and login item.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Reset All Data...") {
                    showResetConfirm = true
                }
                .foregroundColor(.red)
            }
        }
    }
}
