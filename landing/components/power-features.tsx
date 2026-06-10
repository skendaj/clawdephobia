"use client";

import { motion } from "framer-motion";
import { Terminal, ArrowLeftRight } from "lucide-react";

const FEATURES = [
  {
    icon: Terminal,
    tag: "New",
    title: "Switch the terminal too",
    body: "Picking an account in the app can re-point the `claude` CLI in your terminal to that same account — a real switch, not just a change in what the app shows. Link each account once with `claude login`, then flip between them from the menu bar.",
    points: [
      "Green status logo when the active account is wired up",
      "Auto-captures refreshed logins so tokens stay valid",
      "Direct-download build — your logins never leave your Mac",
    ],
  },
  {
    icon: ArrowLeftRight,
    tag: "New",
    title: "Auto-switch when usage runs low",
    body: "When an account crosses 95% on its 5-hour or 7-day limit, Clawdephobia moves you to whichever account has the most headroom — and brings the terminal along if it's linked.",
    points: [
      "Notify me, ask first, or switch automatically",
      "Always jumps to the freshest account",
      "Fires once per episode — no nagging",
    ],
  },
] as const;

export function PowerFeatures() {
  return (
    <section className="px-4 py-14 md:py-20">
      <div className="mx-auto max-w-5xl">
        <h2 className="font-display font-bold tracking-[-0.025em] text-3xl md:text-5xl text-center mb-14">
          One switcher for the app and your terminal.
        </h2>
        <div className="grid gap-8 md:grid-cols-2">
          {FEATURES.map((f, i) => {
            const Icon = f.icon;
            return (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 24 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-60px" }}
                transition={{ duration: 0.6, delay: i * 0.08 }}
                className="rounded-[var(--radius-shot)] border border-black/5 bg-white/40 p-7 card-shadow"
              >
                <div className="flex items-center gap-3">
                  <span className="inline-flex h-11 w-11 items-center justify-center rounded-xl bg-[#d97757]/12 text-[#d97757]">
                    <Icon className="h-6 w-6 stroke-[1.7]" />
                  </span>
                  <span className="text-[11px] uppercase tracking-[0.18em] font-semibold text-[#d97757]">
                    {f.tag}
                  </span>
                </div>
                <h3 className="mt-5 font-display font-semibold text-xl tracking-tight">
                  {f.title}
                </h3>
                <p className="mt-2 text-[14.5px] text-graphite/80 leading-relaxed">
                  {f.body}
                </p>
                <ul className="mt-4 space-y-2">
                  {f.points.map((p, j) => (
                    <li
                      key={j}
                      className="flex items-start gap-2 text-[14px] text-graphite/80"
                    >
                      <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-[#d97757]" />
                      <span>{p}</span>
                    </li>
                  ))}
                </ul>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
