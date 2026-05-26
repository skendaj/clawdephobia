# Clawdephobia

> macOS menu bar app that monitors your Claude AI usage limits in real time. Free, open-source, local-first.

**Clawdephobia** is a lightweight macOS menu bar app for tracking Claude AI usage and rate limits. Free, open-source, requires no API key — only your Claude session cookie. Runs natively on macOS 13+.

## The Problem

The fear of hitting your Claude limits. Clawdephobia shows your 5-hour and 7-day usage at a glance — across every account, right from your menu bar.

## What It Does

- **Live percentage bars** for 5-hour rolling and 7-day weekly limits, directly in your menu bar
- **Per-model tracking** for Opus and Sonnet separately, plus Cowork and Extra usage where applicable
- **Multi-account** support with instant switching from the popover
- **Adaptive polling**: every 30s when usage > 80%, slower when idle (configurable base interval)
- **Pacing warnings**: projects whether you'll exhaust your quota before the window resets, flame indicator in menu bar
- **Phone push notifications** via ntfy.sh to iPhone/Android when limits are near; critical alerts bypass Do Not Disturb
- **macOS WidgetKit widget** for Notification Center (macOS 13+) and desktop (macOS 14+ Sonoma)
- **Enterprise / pay-as-you-go support**: shows credit spend and monthly reset date, auto-detected
- **Service-down detection** with visual indicator after 3 consecutive failures
- **100% local** — no analytics, no tracking, no third-party servers except claude.ai

## Three Steps to Run

1. **Paste your session key** — grab the `sessionKey` cookie from claude.ai. Stays in macOS Keychain.
2. **Watch every limit at a glance** — 5-hour session, 7-day weekly, Opus, Sonnet, Cowork, Extra — live progress, live reset countdowns.
3. **Tune notifications & accounts** — per-account labels, thresholds, ntfy push to your phone, auto-refresh cadence, launch at login.

## Key Facts

- **Price:** Free
- **License:** MIT open-source
- **Platform:** macOS 13 Ventura and later
- **Auth:** Claude session cookie (no API key)
- **Privacy:** Local-first; session key stored in macOS Keychain
- **Download:** https://github.com/skendaj/clawdephobia/releases/latest/download/Clawdephobia.dmg
- **Mac App Store:** https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12
- **Source:** https://github.com/skendaj/clawdephobia
- **Website:** https://clawdephobia.vercel.app

## Related Pages

- [Download](https://clawdephobia.vercel.app/download.md) — step-by-step install guide
- [FAQs](https://clawdephobia.vercel.app/faqs.md) — detailed Q&A
- [Privacy](https://clawdephobia.vercel.app/privacy.md) — data handling
- [llms.txt](https://clawdephobia.vercel.app/llms.txt) · [llms-full.txt](https://clawdephobia.vercel.app/llms-full.txt)
