"use client";

import { motion } from "framer-motion";
import {
  Users,
  Activity,
  Bell,
  Smartphone,
  Flame,
  CreditCard,
  Share2,
  ShieldCheck,
  Terminal,
  ArrowLeftRight,
} from "lucide-react";
import { Scribble } from "@/components/highlight";

const FEATURES = [
  { icon: Users, label: "Multiple\naccounts" },
  { icon: Terminal, label: "Switch the\nterminal too" },
  { icon: ArrowLeftRight, label: "Auto-switch\non low usage" },
  { icon: Activity, label: "Live usage\nbars" },
  { icon: Bell, label: "Smart\nnotifications" },
  { icon: Smartphone, label: "Phone push\nvia ntfy" },
  { icon: Flame, label: "Pacing\nwarnings" },
  { icon: CreditCard, label: "Enterprise\ncredits" },
  { icon: Share2, label: "Share\ncards" },
  { icon: ShieldCheck, label: "100% local\n& private", emphasis: true },
] as const;

export function FeatureGrid() {
  return (
    <section className="px-4 py-10 md:py-14">
      <motion.div
        initial="hidden"
        whileInView="show"
        viewport={{ once: true, margin: "-80px" }}
        variants={{
          hidden: {},
          show: { transition: { staggerChildren: 0.05 } },
        }}
        className="mx-auto max-w-5xl grid grid-cols-2 md:grid-cols-4 gap-x-6 gap-y-12 md:gap-y-14"
      >
        {FEATURES.map((f, i) => {
          const Icon = f.icon;
          return (
            <motion.div
              key={i}
              variants={{
                hidden: { opacity: 0, y: 16 },
                show: { opacity: 1, y: 0, transition: { duration: 0.5 } },
              }}
              className="flex flex-col items-center text-center gap-3"
            >
              <Icon className="h-8 w-8 stroke-[1.6]" />
              <p className="text-[15px] md:text-[16px] font-semibold leading-tight whitespace-pre-line">
                {"emphasis" in f && f.emphasis ? (
                  <Scribble>{f.label}</Scribble>
                ) : (
                  f.label
                )}
              </p>
            </motion.div>
          );
        })}
      </motion.div>
    </section>
  );
}
