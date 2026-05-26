"use client";

import dynamic from "next/dynamic";
import { Github } from "lucide-react";
import { ApplePlain } from "@/components/icons/apple-plain";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Highlight } from "@/components/highlight";

const HeroScene = dynamic(
  () => import("./hero-scene").then((m) => m.HeroScene),
  { ssr: false }
);

const DOWNLOAD_URL =
  "https://github.com/skendaj/clawdephobia/releases/latest/download/Clawdephobia.dmg";
const REPO_URL = "https://github.com/skendaj/clawdephobia";
const APP_STORE_URL =
  "https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12";

const titleWords = ["Claude", "usage", "limits."];
const titleEm = ["Right", "in", "your", "menu", "bar."];

export function Hero() {
  return (
    <section className="relative pt-[64px] md:pt-14 pb-6 md:pb-8 px-4">
      <div className="relative z-10 mx-auto max-w-5xl text-center">
        <div className="mx-auto -mb-2 md:-mb-4 h-[120px] md:h-[150px] w-full max-w-md pointer-events-none">
          <HeroScene />
        </div>
        <motion.h1
          initial="hidden"
          animate="show"
          variants={{
            hidden: {},
            show: { transition: { staggerChildren: 0.06 } },
          }}
          className="font-display font-bold tracking-[-0.035em] leading-[0.98] text-[44px] sm:text-[64px] md:text-[84px] lg:text-[96px] text-ink"
        >
          <span className="block">
            {titleWords.map((w, i) => (
              <Word key={i}>{w}</Word>
            ))}
          </span>
          <span className="block mt-1 md:mt-2">
            {titleEm.slice(0, 3).map((w, i) => (
              <Word key={i}>{w}</Word>
            ))}{" "}
            <Highlight>
              {titleEm.slice(3).map((w, i) => (
                <Word key={i}>{w}</Word>
              ))}
            </Highlight>
          </span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6, duration: 0.6 }}
          className="mt-5 mx-auto max-w-xl text-[15px] md:text-[17px] text-graphite/85 leading-relaxed"
        >
          The fear of hitting your Claude limits. See 5-hour and 7-day usage at
          a glance — across every account, right from your menu bar.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.75, duration: 0.6 }}
          className="mt-7 flex items-center justify-center gap-3 flex-wrap"
        >
          <Button asChild size="lg">
            <a href={DOWNLOAD_URL}>
              <ApplePlain className="h-4 w-4" />
              Download for Mac
            </a>
          </Button>
          <Button asChild size="lg" variant="soft">
            <a href={REPO_URL} target="_blank" rel="noreferrer">
              <Github className="h-4 w-4" />
              View on GitHub
            </a>
          </Button>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1, duration: 0.6 }}
          className="mt-5 flex items-center justify-center gap-2 flex-wrap text-[12.5px] text-mute"
        >
          <span>Free · Open source · macOS 13+</span>
          <span className="hidden sm:inline text-mute/50">·</span>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 rounded-full border border-line bg-cream-2 px-2.5 py-0.5 text-[11px] font-medium text-graphite hover:bg-cream-3 transition-colors"
          >
            <ApplePlain className="h-3 w-3" />
            Mac App Store
          </a>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.15, duration: 0.6 }}
          className="mt-4 md:mt-6 text-mute text-[13px]"
        >
          ▸ Psst… it&apos;s built for power users.
        </motion.p>
      </div>
    </section>
  );
}

function Word({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-block overflow-hidden align-baseline mr-[0.22em] last:mr-0">
      <motion.span
        variants={{
          hidden: { y: "110%" },
          show: { y: "0%", transition: { duration: 0.7, ease: [0.2, 0.7, 0.2, 1] } },
        }}
        className="inline-block"
      >
        {children}
      </motion.span>
    </span>
  );
}
