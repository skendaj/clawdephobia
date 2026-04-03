import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case notifications = "Notifications"
    case phone = "Phone"
    case account = "Account"
    case data = "Data"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .phone: return "iphone"
        case .account: return "key"
        case .data: return "externaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    var onClose: () -> Void

    @State private var selectedTab: SettingsTab = .general
    @State private var newSessionKey: String = ""
    @State private var showResetConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                AppIconView(size: 52)

                Text("Fear of hitting Claude limits")
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
            Text("This deletes all Claudephobia data including your session key from Keychain and removes the login item.")
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

                Picker("Progress style", selection: Binding(
                    get: { viewModel.progressStyle },
                    set: { viewModel.setProgressStyle($0) }
                )) {
                    Text("Bars").tag(0)
                    Text("Circles").tag(1)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
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

                Text("Start Claudephobia automatically when you log in")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button("Quit Claudephobia") {
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
            Text("Get Claudephobia alerts on your phone via ntfy.sh \u{2014} a free, open-source push service. Works with iOS and Android.")
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
                        Label("Subscribe to a unique topic (e.g. claudephobia-yourname)", systemImage: "2.circle")
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

                    TextField("e.g. claudephobia-yourname123", text: Binding(
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

    // MARK: - Account

    private var accountTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Session key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Stored securely in macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                SecureField("Paste new session key...", text: $newSessionKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        let key = newSessionKey.trimmingCharacters(in: .whitespaces)
                        if !key.isEmpty {
                            viewModel.updateSessionKey(key)
                            newSessionKey = ""
                        }
                    }

                Button("Update Session Key") {
                    let key = newSessionKey.trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        viewModel.updateSessionKey(key)
                        newSessionKey = ""
                    }
                }
                .disabled(newSessionKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Claudephobia reads your usage data directly from the Claude API using your session cookie. No data is sent to any third party. No cost involved.")
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

                Text("Remove all Claudephobia data including session key, settings, and login item.")
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
