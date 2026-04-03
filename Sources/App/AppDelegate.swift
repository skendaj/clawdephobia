import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: UsageViewModel!
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        viewModel = UsageViewModel()

        // Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Popover — SwiftUI content determines size
        popover = NSPopover()
        popover.behavior = .transient
        let hostingController = NSHostingController(rootView: PopoverView(viewModel: viewModel))
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        updateMenuBarDisplay()

        // Re-render menu bar when any relevant property changes
        Publishers.CombineLatest(
            Publishers.CombineLatest(
                Publishers.CombineLatest4(
                    viewModel.$sessionPercent,
                    viewModel.$weeklyPercent,
                    viewModel.$menuBarDisplayMode,
                    viewModel.$isPacingWarning
                ),
                viewModel.$isServiceDown
            ),
            viewModel.$progressStyle
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.updateMenuBarDisplay()
        }
        .store(in: &cancellables)

        // Open settings window when requested
        viewModel.$showSettingsWindow
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.showSettingsWindow = false
                self?.closePopover()
                self?.showSettings()
            }
            .store(in: &cancellables)

        // Resize popover when switching between setup/usage views
        viewModel.$isSetupComplete
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.popover.isShown, let button = self.statusItem.button else { return }
                self.popover.performClose(nil)
                DispatchQueue.main.async {
                    self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
            .store(in: &cancellables)

        // Handle share actions — close popover first, then perform action
        viewModel.$pendingShareAction
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                self?.viewModel.pendingShareAction = nil
                self?.closePopover()
                // Small delay so popover finishes closing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.performShareAction(action)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu Bar

    private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        button.image = MenuBarRenderer.createImage(
            sessionPercent: viewModel.sessionPercent,
            weeklyPercent: viewModel.weeklyPercent,
            isPacingWarning: viewModel.isPacingWarning,
            isServiceDown: viewModel.isServiceDown,
            progressStyle: viewModel.progressStyle
        )
        button.imagePosition = .imageLeading

        button.title = MenuBarRenderer.titleText(
            sessionPercent: viewModel.sessionPercent,
            weeklyPercent: viewModel.weeklyPercent,
            displayMode: viewModel.menuBarDisplayMode
        )

        button.toolTip = MenuBarRenderer.tooltip(
            sessionPercent: viewModel.sessionPercent,
            sessionReset: viewModel.sessionResetDescription,
            weeklyPercent: viewModel.weeklyPercent,
            weeklyReset: viewModel.weeklyResetDescription,
            isServiceDown: viewModel.isServiceDown
        )
    }

    // MARK: - Edit Menu (enables Cmd+C/V/X/A in text fields)

    private func setupEditMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu

        if NSApp.mainMenu == nil {
            NSApp.mainMenu = NSMenu()
        }
        NSApp.mainMenu?.addItem(editMenuItem)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            viewModel.fetchUsageIfStale()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Share Actions

    private func performShareAction(_ action: ShareAction) {
        switch action {
        case .shareImage:
            guard let image = ShareCardRenderer.renderImage(from: viewModel),
                  let button = statusItem.button else { return }
            let picker = NSSharingServicePicker(items: [image])
            picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        case .copyImage:
            _ = ShareCardRenderer.copyToClipboard(from: viewModel)

        case .saveImage:
            ShareCardRenderer.saveToFile(from: viewModel)

        case .exportJSON:
            viewModel.exportToFile()
        }
    }

    // MARK: - Settings Window

    private func showSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
            return
        }
        let settingsView = SettingsView(viewModel: viewModel) { [weak self] in
            self?.closeSettingsWindow()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.title = "Claudephobia Settings"
        window.delegate = self
        window.isReleasedWhenClosed = false

        // Become regular app so macOS manages window layering normally
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        settingsWindow = window
    }

    private func closeSettingsWindow() {
        settingsWindow?.orderOut(nil)
        DispatchQueue.main.async { [weak self] in
            self?.settingsWindow = nil
            // Revert to accessory app (no dock icon)
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        closeSettingsWindow()
    }
}
