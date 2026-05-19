"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { useState } from "react";
import { Lightbox } from "./lightbox";

const STEPS = [
  {
    src: "/shots/setup.png",
    title: "Paste your session key",
    body: "Grab the sessionKey cookie from claude.ai. Stays in your macOS Keychain — never leaves your Mac.",
  },
  {
    src: "/shots/popover.png",
    title: "Watch every limit at a glance",
    body: "5-hour session, 7-day weekly, Opus, Sonnet, Cowork, Extra usage — live progress, live reset countdowns.",
  },
  {
    src: "/shots/settings.png",
    title: "Tune notifications & accounts",
    body: "Per-account labels, thresholds, ntfy push to your phone, auto-refresh cadence, launch at login.",
  },
];

const LIGHTBOX_ITEMS = STEPS.map((s) => ({ src: s.src, alt: s.title }));

export function Walkthrough() {
  const [index, setIndex] = useState<number | null>(null);

  return (
    <section className="px-4 py-14 md:py-20">
      <div className="mx-auto max-w-5xl">
        <h2 className="font-display font-bold tracking-[-0.025em] text-3xl md:text-5xl text-center mb-14">
          Three steps. Then it just runs.
        </h2>
        <div className="grid gap-10 md:grid-cols-3">
          {STEPS.map((s, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-60px" }}
              transition={{ duration: 0.6, delay: i * 0.08 }}
            >
              <button
                type="button"
                onClick={() => setIndex(i)}
                aria-label={`Open ${s.title} screenshot`}
                className="group relative block w-full aspect-[5/3] overflow-hidden rounded-[var(--radius-shot)] bg-gradient-to-br from-[#2a1f1a] to-[#5e3a26] card-shadow cursor-zoom-in focus:outline-none focus-visible:ring-2 focus-visible:ring-[#d97757] focus-visible:ring-offset-2"
              >
                <Image
                  src={s.src}
                  alt={s.title}
                  fill
                  sizes="(max-width: 768px) 100vw, 400px"
                  className="object-contain p-4 transition-transform duration-500 group-hover:scale-[1.03]"
                />
              </button>
              <p className="mt-5 text-[11px] uppercase tracking-[0.18em] text-mute font-semibold">
                Step {i + 1}
              </p>
              <h3 className="mt-1 font-display font-semibold text-xl tracking-tight">
                {s.title}
              </h3>
              <p className="mt-2 text-[14.5px] text-graphite/80 leading-relaxed">
                {s.body}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
      <Lightbox items={LIGHTBOX_ITEMS} index={index} onIndexChange={setIndex} />
    </section>
  );
}
