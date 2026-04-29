<p align="center">
  <img src="Resources/icon.png" width="128" height="128" alt="clawdephobia icon">
</p>

<h1 align="center">Clawdephobia</h1>

<p align="center"><em>The fear of hitting your Claude limits.</em></p>

<p align="center">A lightweight macOS menu bar app that monitors your AI assistant usage limits in real time.<br>See your 5-hour session and 7-day weekly usage at a glance — no browser tab required.</p>

<p align="center">
  <a href="https://github.com/skendaj/clawdephobia/releases/latest/download/clawdephobia.zip">
    <img src="https://img.shields.io/badge/Download-clawdephobia.zip-D97757?style=for-the-badge&logo=apple&logoColor=white" alt="Download">
  </a>
</p>

## How It Works

Clawdephobia uses your Claude session cookie to read usage data directly from the Claude API. It tracks:

- **5-hour session limit** — the rolling short-term rate limit
- **7-day weekly limit** — the rolling long-term rate limit
- **Model-specific limits** — Opus, Sonnet, OAuth Apps, and Cowork weekly limits (when available)
- **Extra usage** — additional usage beyond your plan (when applicable)
- **Pacing indicator** — warns if you're burning through your session limit too fast

No data is sent to any third party. Everything runs locally on your Mac.

## Getting Your Session Key

1. Sign in to your AI assistant's web app in a browser
2. Open DevTools (`Cmd + Option + I`)
3. Go to **Application** → **Cookies** and select the site
4. Find the cookie named `sessionKey` and copy its value

The key looks like `sk-ant-sid01-...`. Paste it into clawdephobia when prompted.

> Your session key is stored in the macOS Keychain and never leaves your machine.

## Install

### Download (recommended)

1. Go to [Releases](../../releases) and download `clawdephobia.zip`
2. Unzip and drag `clawdephobia.app` to your Applications folder
3. Right-click the app → **Open** (required on first launch to bypass Gatekeeper)

The app is code-signed and notarized by Apple, so subsequent launches work normally.

### Build from source

Requires **macOS 13+** and **Swift 5.9+**.

```bash
# Build the .app bundle
./scripts/build-app.sh

# The app is in dist/clawdephobia.app — double-click or:
open dist/clawdephobia.app
```

Or for development:

```bash
swift build
.build/debug/clawdephobia
```

You can also open `Package.swift` in Xcode and hit Run (`Cmd + R`).

## Features

### Menu Bar

- Dual progress bars showing session (top) and weekly (bottom) usage
- Color-coded status dot — green (normal), orange (>70%), red (>90%), grey (service down)
- Optional percentage text next to the icon (three display modes)
- Flame icon when pacing is unsustainable
- Cloud icon when Claude's service is unreachable
- Tooltip with usage percentages and reset countdowns

### Popover

Click the menu bar icon to see:

- Detailed usage for all active limits with color-coded progress bars
- Live reset countdown timers for each limit (updates every second)
- Rate limit tier display
- Service-down banner when Claude is unreachable
- Error banners for auth/connection issues
- Share menu to export your usage as an image or JSON
- Manual refresh button and "last updated" timestamp

### Share Card

Generate a styled dark-themed usage report card that you can:

- **Share** via macOS share sheet
- **Copy** to clipboard as PNG
- **Save** as PNG to your Desktop
- **Export** as JSON for external tools

The card includes your plan tier, a status tag (Active/Warning/Critical), hero usage number, all monitored limits with progress bars, pacing warnings, and a timestamp.

### Notifications

Native macOS notifications with sound and app icon for:

- **Warning** — when usage crosses a configurable threshold (75%, 80%, or 90%)
- **Critical** — when usage hits critical levels (90%, 95%, or 100%)
- **Restored** — when a rate limit window resets and usage drops back down
- **Service Down** — when Claude becomes unreachable (fires once per incident)

Notifications are stateful — they fire once per threshold crossing and reset when usage drops.

Use the **Send Test Notification** button in Settings to verify notifications work.

### Phone Notifications

Get clawdephobia alerts on your phone (iOS or Android) via [ntfy.sh](https://ntfy.sh) — a free, open-source push notification service:

1. Install the **ntfy** app ([App Store](https://apps.apple.com/app/ntfy/id1625396347) or [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy))
2. Subscribe to a unique topic (e.g. `clawdephobia-yourname123`)
3. In clawdephobia Settings → **Phone**, enable phone notifications and enter the same topic
4. Hit **Send Test to Phone** to verify

All alerts (warning, critical, reset, service down) are mirrored to your phone. Critical alerts use urgent priority to break through Do Not Disturb. You can also [self-host ntfy](https://docs.ntfy.sh/install/) for complete privacy.

### Service Down Detection

clawdephobia detects when Claude's service is unavailable:

- Triggers after 3 consecutive server/network failures
- Displays a red banner in the popover with "Showing last known data"
- Grey status dot and cloud icon in the menu bar
- Sends a one-time notification
- Auto-recovers when the service comes back online

### Smart Auto-Refresh

- Configurable base interval: 1, 5, or 10 minutes
- **Adaptive polling** — speeds up as usage increases:
  - Usage > 80%: refreshes every 30 seconds
  - Usage > 50%: refreshes at half the configured interval
  - Otherwise: uses the configured interval
- **Auto-refreshes on system wake** and **network reconnection**
- **Popover-triggered refresh** with 30-second cooldown to prevent hammering
- **Retry with exponential backoff** on transient failures (up to 3 attempts)

### Settings

Six-tab settings window:

- **General** — text display mode (icon only / icon + percentages / icon + compact), auto-refresh interval, launch at login
- **Notifications** — enable/disable, warning and critical thresholds, monitored limits list, reset notifications toggle, test notification button
- **Phone** — enable phone push notifications via ntfy.sh, topic and server URL configuration, test button
- **Account** — update your session key (stored securely in Keychain)
- **Data** — export usage as JSON, reset all data (clears Keychain, UserDefaults, LaunchAgent)
- **About** — privacy statement, open-source info, author credit

### Launch at Login

Toggle in Settings → General. Creates a standard macOS LaunchAgent at `~/Library/LaunchAgents/com.claudephobia.app.plist`.

## Architecture

```
Sources/
├── main.swift                          # Entry point (manual NSApplication lifecycle)
├── App/
│   ├── AppDelegate.swift               # Status item, popover, settings window
│   └── MenuBarRenderer.swift           # Menu bar icon drawing (CoreGraphics)
├── Services/
│   ├── ClaudeAPIClient.swift           # Claude API client & data models
│   ├── UsageScraper.swift              # Fetches /usage and /rate_limits
│   ├── KeychainHelper.swift            # macOS Keychain wrapper
│   ├── NotificationManager.swift       # macOS notifications + ntfy.sh push
│   └── PushNotificationService.swift   # Phone push via ntfy.sh (iOS/Android)
├── ViewModels/
│   └── UsageViewModel.swift            # Central state, settings, refresh logic
└── Views/
    ├── PopoverView.swift               # Setup flow & usage dashboard
    ├── SettingsView.swift              # Tabbed settings window
    └── ShareCardView.swift             # Share card generation & rendering
```

The app uses an **AppKit + SwiftUI hybrid** approach — `NSStatusItem` for the menu bar, `NSPopover` with `NSHostingController` for the popover, and pure SwiftUI for all views. State flows through a single `UsageViewModel` observed by all views via Combine. Zero external dependencies.

## Privacy

- **No third-party servers** — communicates only with `claude.ai`
- **No tracking or analytics**
- **Session key stored in macOS Keychain** — not in plain text
- **All data stays on your Mac**
- **Easy full reset** from Settings → Data → Reset All Data

## License

MIT
