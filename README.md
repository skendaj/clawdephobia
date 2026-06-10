<p align="center">
  <img src="Resources/icon-rounded.png" width="128" height="128" alt="clawdephobia icon">
</p>

<h1 align="center">Clawdephobia</h1>

<p align="center"><em>The fear of hitting your Claude limits.</em></p>

<p align="center">A lightweight macOS menu bar app that monitors your AI assistant usage limits in real time.<br>See your 5-hour session and 7-day weekly usage at a glance — no browser tab required.<br>Track multiple Claude accounts (personal, work, enterprise) from a single switcher.</p>

<p align="center">
  <a href="https://clawdephobia.vercel.app">
    <img src="https://img.shields.io/badge/Website-clawdephobia.vercel.app-1F1E1D?style=for-the-badge&logo=vercel&logoColor=white" alt="Website">
  </a>
  <a href="https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12">
    <img src="https://img.shields.io/badge/Mac_App_Store-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Mac App Store">
  </a>
  <a href="https://github.com/skendaj/Claudephobia/releases/latest/download/Clawdephobia.dmg">
    <img src="https://img.shields.io/badge/DMG_GitHub-D97757?style=for-the-badge&logo=github&logoColor=white" alt="Download DMG">
  </a>
</p>

<p align="center">
  <a href="https://clawdephobia.vercel.app">Home</a> ·
  <a href="https://github.com/skendaj/Claudephobia/releases">Releases</a> ·
  <a href="https://clawdephobia.vercel.app/faqs">FAQs</a> ·
  <a href="https://clawdephobia.vercel.app/download">Download</a> ·
  <a href="https://clawdephobia.vercel.app/privacy">Privacy</a>
</p>

<p align="center">
  <img src="landing/public/shots/popover.png" width="32%" alt="Popover with live usage bars">
  <img src="landing/public/shots/settings.png" width="32%" alt="Settings window">
  <img src="landing/public/shots/setup.png" width="32%" alt="Setup screen">
</p>

## How It Works

Clawdephobia uses your Claude session cookie to read usage data directly from the Claude API. It tracks:

- **5-hour session limit** — the rolling short-term rate limit
- **7-day weekly limit** — the rolling long-term rate limit
- **Model-specific limits** — Opus, Sonnet, Claude Design, OAuth Apps, and Cowork weekly limits (when available)
- **Extra usage** — additional usage beyond your plan (when applicable)
- **Enterprise / pay-as-you-go credits** — spend amount, monthly cap (when set), and next reset date for credits-based plans
- **Pacing indicator** — warns if you're burning through your session limit too fast
- **Multiple accounts** — switch between personal, work, and enterprise accounts from a single menu bar app

No data is sent to any third party. Everything runs locally on your Mac.

## Getting Your Session Key

1. Sign in to your AI assistant's web app in a browser
2. Open DevTools (`Cmd + Option + I`)
3. Go to **Application** → **Cookies** and select the site
4. Find the cookie named `sessionKey` and copy its value

The key looks like `sk-ant-sid01-...`. Paste it into clawdephobia when prompted.

> Your session key is stored in the macOS Keychain and never leaves your machine.

> **Stay signed in.** Session keys expire when you sign out of claude.ai. Keep the account signed in on the browser you grabbed the key from — otherwise the app will prompt you to paste a fresh one.

> **No session key?** Hit **Try Demo Mode** on the setup screen to explore the app with realistic mock data — no account required.

## Install

### Mac App Store (recommended)

Get it from the [Mac App Store](https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12) — one-click install with automatic updates.

### Download DMG

1. Go to [Releases](../../releases) and download `Clawdephobia.dmg`
2. Open the DMG and drag `Clawdephobia.app` to your Applications folder
3. Right-click the app → **Open** (required on first launch to bypass Gatekeeper)

The app is code-signed and notarized by Apple, so subsequent launches work normally.

### Build from source

Requires **macOS 13+**, **Swift 5.9+**, and **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** (`brew install xcodegen`).

```bash
# Regenerate the Xcode project (project.yml → Clawdephobia.xcodeproj)
xcodegen generate

# Build the signed/notarized .app bundle
./scripts/build-app.sh
# Result: dist/Clawdephobia.app
```

Or for development:

```bash
xcodegen generate
open Clawdephobia.xcodeproj
# In Xcode, hit Cmd+R
```

> `swift build` is no longer supported — the project uses XcodeGen + xcodebuild to support the widget extension target. `Clawdephobia.xcodeproj` is gitignored; regenerate after pulling.

## Features

### Multiple Accounts

Manage every Claude account you have — personal, work, client, enterprise — from one menu bar app.

- **Account switcher** in the popover header — one click to flip between accounts. Dropdown shows compact `82% / 41%` peek of each account's 5h/7d usage so you know which one is hot before switching
- **Auto-detected labels** — Clawdephobia reads the org name from the Claude API on add (e.g. `My Workspace`). Rename freely from Settings → Accounts
- **Per-account state** — notification throttles, reset countdowns, and last-known data live separately for each account. Switching back to an account restores its data instantly (no flash of zero)
- **Smart polling** — the active account refreshes on the configured cadence; inactive accounts are sampled every 10 minutes (and on popover open with a 30-second cooldown) so the switcher peek stays fresh without burning API calls
- **Label-prefixed notifications** — alerts include the account name (`Work — 5-hour session at 92%`) so you always know which account just tripped a threshold
- **Auto-switch on add** — pasting a new session key immediately makes that account active so you can confirm it works
- **Add accounts from anywhere** — from the popover switcher's "Add account…" sheet or from Settings → Accounts

### Switch the Terminal Too (Claude Code CLI)

Switching the active account can also re-point the `claude` CLI in your terminal to that account — a *real* switch, not just a change in what the app displays.

- **How it works** — the `claude` CLI keeps its login in the macOS Keychain (`Claude Code-credentials`). Clawdephobia snapshots that login per account and restores the right one when you switch. Because session keys (claude.ai cookies) and the CLI's OAuth tokens are different credentials, you link each account once: run `claude login` for it, then click the **terminal icon** on its row in Settings → Accounts to capture the login
- **Opt-in** — turn on *"Switch the terminal login when I change accounts"* in Settings → Accounts. Off by default, since it rewrites another app's Keychain item (you'll get a one-time macOS "Always Allow" prompt)
- **Auto-capture** — once an account is linked, switching away from it re-snapshots its current login so token refreshes are preserved; switching to a linked account restores it
- **Running sessions** — an already-running `claude` session keeps its old login until you start a new one. The popover shows a brief reminder when that applies
- **Direct-download only** — this feature needs to read another app's Keychain item, which the Mac App Store sandbox forbids. It's available in the **direct-download (DMG)** build only; in the App Store build the controls are hidden

### Enterprise / Pay-as-You-Go

Enterprise plans on Claude bill by credits instead of percentage-capped windows. Clawdephobia detects this automatically and switches to a credits view:

- **Spend amount** — formatted in the plan's currency (e.g. `$14.37 of $100.00`), pulled from Claude's authoritative `/overage_spend_limit` endpoint
- **Prepaid credit balance** — when the org has prepaid credits, the remaining balance is shown alongside the spend total (e.g. `Balance $25.00`), pulled from `/prepaid/credits`
- **`Unlimited` badge** when there's no monthly cap, **`Capped`** with a progress bar when there is
- **Monthly reset date** — computed as the 1st of next month (e.g. `Resets Jun 1`)
- **Single menu bar indicator** — enterprise accounts get a single bar or circle in the menu bar reflecting credit usage (no dual session/weekly bars)
- 5-hour and 7-day rows are hidden for true credits-only accounts but Pro accounts that *also* enable `extra_usage` keep both views simultaneously

### Expired Sessions

When a session key stops working (you signed out of claude.ai, the cookie rotated, etc.):

- The popover shows an orange `Session expired` banner with an **Update →** button
- Tapping the banner opens the add-account sheet pre-wired to **upsert** — paste the new key and Clawdephobia rotates the Keychain entry for the same org without losing your label or settings
- **Same-id rotation is instant** — pasting a rotated key for an already-active account immediately shows a loading state and re-attaches the data pipeline without flashing empty bars
- If a successful snapshot existed before expiry, the cached usage bars stay visible (dimmed) underneath the banner so you can still see your last-known state
- Account switching never blanks the popover — last-known data hydrates from the in-memory snapshot before the next fetch completes

### Menu Bar

- **Pro plans** — dual progress bars showing session (top) and weekly (bottom) usage for the active account
- **Enterprise plans** — single dedicated bar or circle reflecting credit usage (auto-switches based on plan type)
- Color-coded status dot — green (normal), orange (>70%), red (>90%), grey (service down)
- Optional percentage text next to the icon (three display modes: icon only, icon + percentages, icon + compact)
- Configurable progress style — bars or circular indicators, set independently for the menu bar icon and the popover content view
- Flame icon when pacing is unsustainable
- Cloud icon when Claude's service is unreachable
- Tooltip with usage percentages and reset countdowns

### Popover

Click the menu bar icon to see:

- **Account switcher** at the top — pick the active account, add new ones, or open the Settings → Accounts tab
- Detailed usage for all active limits with color-coded progress bars (5h, 7d, Opus, Sonnet, OAuth Apps, Cowork, Claude Design, Extra usage, Promotional)
- **Active / Inactive grouping** — rows in use render at the top; everything at 0% collapses into an `Inactive limits · N` accordion (default closed) so the popover stays compact
- Live reset countdown timers for each limit (updates every second)
- Rate limit tier display
- Enterprise / pay-as-you-go credits row when applicable
- Session-expired banner with one-click **Update Key** button
- Service-down banner when Claude is unreachable
- Error banners for auth/connection issues
- Share menu to export your usage as an image or JSON
- Manual refresh button, "last updated" timestamp, and per-account "Remove" with confirmation

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
- **Restored** — when a rate limit window resets and usage drops below 5% (only fires if it was previously above 20%)
- **Service Down** — when Claude becomes unreachable (fires once per incident)

Notifications are stateful — they fire once per threshold crossing and reset when usage drops. **Per-account throttle state** means each account fires its own notifications independently and tracks its own thresholds.

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
- **Rate limit backoff** — HTTP 429 responses reschedule the next fetch to 60 seconds

### Settings

Six-tab settings window:

- **General** — text display mode, progress style (bars/circles), auto-refresh interval, launch at login
- **Notifications** — enable/disable, warning and critical thresholds, monitored limits list, reset notifications toggle, test notification button
- **Phone** — enable phone push notifications via ntfy.sh, topic and server URL configuration, test button
- **Accounts** — list every configured account with active selection (radio), 5h/7d peek, inline rename, remove (with confirm), `+ Add account` button, and demo mode toggle. Each account's session key lives in Keychain under its org UUID
- **Data** — export usage as JSON, reset all data (clears Keychain, UserDefaults, launch-at-login registration, and every account's session key)
- **About** — privacy statement, open-source info, author credit

### Automatic Update Checks

Clawdephobia silently checks GitHub for new releases every 6 hours. When a newer version is available, a banner appears in the popover with a link to the release. You can dismiss it per-version — it won't reappear for the same release.

### Launch at Login

Toggle in Settings → General. Uses the macOS SMAppService API (macOS 13+) — no manual plist required.

## Architecture

```
Sources/
├── main.swift                          # Entry point (manual NSApplication lifecycle)
├── App/
│   ├── AppDelegate.swift               # Status item, popover, settings window, wires AccountStore + ViewModel
│   └── MenuBarRenderer.swift           # Menu bar icon drawing (CoreGraphics)
├── Models/
│   └── Account.swift                   # Account + AccountPeek structs
├── Services/
│   ├── ClawdAPIClient.swift            # Claude API client, ClawdUsageData, ExtraUsageInfo, OrgInfo
│   ├── UsageScraper.swift              # Fetches /organizations, /usage, /rate_limits
│   ├── AccountStore.swift              # Multi-account CRUD, active selection, snapshot cache, inactive polling
│   ├── KeychainHelper.swift            # macOS Keychain wrapper (per-account keys)
│   ├── NotificationManager.swift       # macOS notifications + ntfy.sh push (per-account throttle state)
│   └── PushNotificationService.swift   # Phone push via ntfy.sh (iOS/Android)
├── ViewModels/
│   └── UsageViewModel.swift            # Central state, settings, refresh logic, snapshot hydration
└── Views/
    ├── PopoverView.swift               # Setup flow, switcher, usage dashboard, expired banner, credits row
    ├── SettingsView.swift              # Tabbed settings window (Accounts tab manages list)
    └── ShareCardView.swift             # Share card generation & rendering
```

The app uses an **AppKit + SwiftUI hybrid** approach — `NSStatusItem` for the menu bar, `NSPopover` with `NSHostingController` for the popover, and pure SwiftUI for all views. State flows through `AccountStore` (multi-account source of truth) and `UsageViewModel` (active-account derived state), both observed by views via Combine. Zero external dependencies.

**Multi-account internals**

- Session keys stored in Keychain under `session_key.<orgUUID>` (per-account)
- Account list serialized to UserDefaults under `clawdephobia.accounts`; active selection under `clawdephobia.active_account_id`
- Legacy single-account installs auto-migrate on first launch (gated by `clawdephobia.accounts_schema_v1`) — the old `session_key` Keychain entry is reassigned to its org UUID after fetching it once
- In-memory `snapshots: [accountId: ClawdUsageData]` survives switches so flipping back to an account paints instantly. Reset on app relaunch
- `isEnterprise` discriminator: `extraCreditsEnabled && !hasSessionLimit && !hasWeeklyLimit` — keeps Pro plans with `extra_usage` enabled from being mistaken for true credits-only accounts

**Terminal sync internals**

- `ClaudeCodeCredentialBridge` reads/writes the CLI's live Keychain item (`Claude Code-credentials`, account = Unix user) and stores per-account snapshots under Clawdephobia's own service as `cc_credentials.<accountId>`
- `AccountStore.setActive` performs the swap: it re-snapshots the outgoing account (only if already linked) then restores the incoming account's snapshot. Gated by the `clawdephobia.sync_terminal_login` opt-in and `ClaudeCodeCredentialBridge.isSupported` (false under the App Store sandbox, detected via `APP_SANDBOX_CONTAINER_ID`)
- Snapshots are removed alongside the session key on account remove / Reset All Data

## Privacy

- **No third-party servers** — communicates only with `claude.ai` (and `ntfy.sh` if you opt into phone notifications)
- **No tracking or analytics**
- **Session keys stored in macOS Keychain** — one entry per account, never in plain text
- **All data stays on your Mac**
- **Easy full reset** from Settings → Data → Reset All Data (clears every account's Keychain entry + UserDefaults + login item)

## License

MIT
