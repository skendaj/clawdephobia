import { Nav } from "@/components/nav";
import { FAQAccordion } from "@/components/faq-accordion";
import { FileText } from "lucide-react";
import Script from "next/script";
import { breadcrumbJsonLd } from "@/lib/breadcrumb";
import type { Metadata } from "next";

const breadcrumbLd = breadcrumbJsonLd([
  { name: "Home", path: "/" },
  { name: "FAQs", path: "/faqs" },
]);

export const metadata: Metadata = {
  title: "FAQs — Clawdephobia: Claude usage tracker for macOS",
  description:
    "Answers to common questions about Clawdephobia — the free macOS menu bar app that monitors Claude AI usage limits, rate limits, and quota in real time.",
  alternates: { canonical: "/faqs" },
  openGraph: {
    title: "Clawdephobia FAQs — Claude usage tracking on macOS",
    description:
      "Session keys, multi-account, push notifications, Pro vs Enterprise. Common questions about Clawdephobia.",
    type: "website",
    url: "/faqs",
    siteName: "Clawdephobia",
  },
  twitter: {
    card: "summary_large_image",
    title: "Clawdephobia FAQs",
    description:
      "Session keys, multi-account, push notifications. Common questions answered.",
  },
};

const faqJsonLd = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: [
    {
      "@type": "Question",
      name: "What is Clawdephobia?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Clawdephobia is a free, open-source macOS menu bar app that monitors your Claude AI usage limits in real time. It shows your 5-hour and 7-day usage as live percentage bars and supports multiple accounts.",
      },
    },
    {
      "@type": "Question",
      name: "What macOS app tracks Claude AI usage limits?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Clawdephobia is the dedicated free and open-source macOS menu bar app for monitoring Claude AI rate limits. It tracks 5-hour rolling usage, 7-day weekly limits, and per-model (Opus/Sonnet) usage.",
      },
    },
    {
      "@type": "Question",
      name: "What is a session key and where do I get one?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "It's the sessionKey cookie from claude.ai. Open DevTools (Cmd+Option+I) → Application → Cookies → claude.ai → copy sessionKey. Paste it into Clawdephobia. It looks like sk-ant-sid01-…",
      },
    },
    {
      "@type": "Question",
      name: "Does Clawdephobia send my data anywhere?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "No third-party servers. The app talks only to claude.ai (and ntfy.sh if you opt into phone push). Session keys live in your macOS Keychain. Everything stays on your Mac.",
      },
    },
    {
      "@type": "Question",
      name: "Does Clawdephobia require an API key?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "No. Clawdephobia uses your Claude session cookie, not an API key. It works for any Claude plan including Pro, Max, and Enterprise.",
      },
    },
    {
      "@type": "Question",
      name: "How does multi-account work?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Add as many accounts as you want from the popover switcher or Settings → Accounts. Each one has its own Keychain entry, notifications, throttles, and last-known data. Switching is instant.",
      },
    },
    {
      "@type": "Question",
      name: "Can Clawdephobia switch my terminal's Claude Code (claude CLI) account?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Yes, in the direct-download build. Enable terminal sync in Settings → Accounts, run claude login for each account once and capture it, and then switching accounts in the app re-points the claude CLI to that account. The Mac App Store build can't do this because the sandbox forbids touching another app's login.",
      },
    },
    {
      "@type": "Question",
      name: "Can Clawdephobia switch accounts automatically when one runs low?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Yes. When an account crosses 95% on its 5-hour or 7-day limit, Clawdephobia can notify you, ask before switching, or switch automatically to whichever account has the most headroom — optionally taking the terminal's claude login along too.",
      },
    },
    {
      "@type": "Question",
      name: "Can I get notifications on my phone when hitting Claude limits?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Yes — via ntfy.sh, a free open-source push service. Install ntfy on iOS or Android, subscribe to a topic, paste the same topic in Settings → Phone. Critical alerts bypass Do Not Disturb.",
      },
    },
    {
      "@type": "Question",
      name: "What's the difference between Pro and Enterprise view?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Pro plans show 5-hour and 7-day percentage bars. Enterprise / pay-as-you-go plans show credits spent in the plan's currency with a monthly reset date. Clawdephobia auto-detects which view to use.",
      },
    },
    {
      "@type": "Question",
      name: "Will there be a Mac App Store version?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Planned. Today the app ships via GitHub Releases (signed and notarized by Apple). Subscribe to the repo to get notified when MAS goes live.",
      },
    },
  ],
};

export default function FAQsPage() {
  return (
    <main className="min-h-screen bg-night text-cream">
      {/* Static hardcoded schema — no user input, no XSS risk */}
      <Script
        id="faq-json-ld"
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
      <script
        type="application/ld+json"
        suppressHydrationWarning
      >{JSON.stringify(breadcrumbLd)}</script>
      <Nav dark />
      <FaqsBody />
      <div className="h-24" />
    </main>
  );
}

function FaqsBody() {
  return (
    <section className="px-4 pt-36 md:pt-44 pb-12 max-w-3xl mx-auto">
      <h1 className="font-display font-bold tracking-[-0.035em] text-[64px] md:text-[96px] leading-[0.95]">
        FAQs
      </h1>
      <p className="mt-3 flex items-center gap-2 text-sm text-cream/60">
        <FileText className="h-4 w-4" />
        Updated May 2026
      </p>
      <div className="mt-12 md:mt-16">
        <FAQAccordion />
      </div>
    </section>
  );
}

// Force the body dark class — handled inline via min-h-screen bg. Layout body
// stays cream by default; this page paints over it.
