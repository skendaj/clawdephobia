"use client";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

const FAQS = [
  {
    q: "What is a session key and where do I get one?",
    a: "It's the sessionKey cookie from claude.ai. Open DevTools (Cmd+Option+I) → Application → Cookies → claude.ai → copy sessionKey. Paste it into Clawdephobia. It looks like sk-ant-sid01-…",
  },
  {
    q: "Does Clawdephobia send my data anywhere?",
    a: "No third-party servers. The app talks only to claude.ai (and ntfy.sh if you opt into phone push). Session keys live in your macOS Keychain. Everything stays on your Mac.",
  },
  {
    q: "Why did the app stop updating? (\"session expired\")",
    a: "Session keys expire when you sign out of claude.ai or when the cookie rotates. Tap the orange banner in the popover → paste a fresh key. Same account, same settings — only the key swaps.",
  },
  {
    q: "How does multi-account work?",
    a: "Add as many accounts as you want from the popover switcher or Settings → Accounts. Each one has its own Keychain entry, notifications, throttles, and last-known data. Switching is instant.",
  },
  {
    q: "What's the difference between Pro and Enterprise view?",
    a: "Pro plans show 5-hour and 7-day percentage bars. Enterprise / pay-as-you-go plans show credits spent in the plan's currency with a monthly reset date. Clawdephobia auto-detects which view to use.",
  },
  {
    q: "Can switching accounts also switch my terminal's claude login?",
    a: "Yes, in the direct-download build. Turn on \"Switch the terminal login when I change accounts\" in Settings → Accounts, run `claude login` for each account once and capture it (the terminal icon on its row). After that, picking an account in the app re-points the `claude` CLI to it. Already-running sessions keep their old login until you start a new one. The Mac App Store build can't do this — the sandbox forbids touching another app's login — so the controls are hidden there.",
  },
  {
    q: "Can it switch accounts automatically when one runs low?",
    a: "Yes. In Settings → Accounts, set what happens when an account crosses 95% on its 5-hour or 7-day limit: just notify you (default), ask before switching, or switch automatically. It jumps to whichever of your other accounts has the most headroom — and takes the terminal along if that account is linked.",
  },
  {
    q: "Can I get notifications on my phone?",
    a: "Yes — via ntfy.sh, a free open-source push service. Install ntfy on iOS or Android, subscribe to a topic, paste the same topic in Settings → Phone. Critical alerts bypass Do Not Disturb.",
  },
  {
    q: "How do I uninstall or reset everything?",
    a: "Settings → Data → Reset All Data clears every Keychain entry, UserDefaults, and the launch-at-login registration. Then drag the app to the Trash.",
  },
  {
    q: "Will there be a Mac App Store version?",
    a: "Planned. Today the app ships via GitHub Releases (signed and notarized by Apple). Subscribe to the repo to get notified when MAS goes live.",
  },
];

export function FAQAccordion() {
  return (
    <Accordion type="single" collapsible className="w-full">
      {FAQS.map((f, i) => (
        <AccordionItem key={i} value={`item-${i}`}>
          <AccordionTrigger>{f.q}</AccordionTrigger>
          <AccordionContent>{f.a}</AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}
