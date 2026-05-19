"use client";

import Image from "next/image";
import { useRef, useState } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import { Lightbox } from "./lightbox";

const SHOT_SRC = "/shots/popover.png";
const SHOT_ALT = "Clawdephobia popover";
const LIGHTBOX_ITEMS = [{ src: SHOT_SRC, alt: SHOT_ALT }];

export function ProductCard() {
  const ref = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState<number | null>(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start end", "end start"],
  });
  const scale = useTransform(scrollYProgress, [0, 0.4, 1], [0.96, 1.02, 0.98]);
  const y = useTransform(scrollYProgress, [0, 1], [40, -40]);

  return (
    <section className="px-4 pb-24 md:pb-32">
      <motion.div
        ref={ref}
        style={{ scale, y }}
        className="mx-auto max-w-5xl"
      >
        <button
          type="button"
          onClick={() => setIndex(0)}
          aria-label="Open popover screenshot"
          className="group relative block w-full overflow-hidden rounded-[28px] bg-gradient-to-b from-[#2a1f1a] via-[#3a2820] to-[#5e3a26] card-shadow cursor-zoom-in focus:outline-none focus-visible:ring-2 focus-visible:ring-[#d97757] focus-visible:ring-offset-2"
        >
          <div className="absolute inset-0 opacity-60 mix-blend-screen pointer-events-none [background:radial-gradient(60%_60%_at_50%_0%,#d97757_0%,transparent_70%)]" />
          <div className="relative aspect-[16/10] md:aspect-[16/9]">
            <Image
              src={SHOT_SRC}
              alt={SHOT_ALT}
              fill
              priority
              sizes="(max-width: 768px) 100vw, 1024px"
              className="object-contain p-6 md:p-10 transition-transform duration-500 group-hover:scale-[1.02]"
            />
          </div>
        </button>
      </motion.div>
      <Lightbox items={LIGHTBOX_ITEMS} index={index} onIndexChange={setIndex} />
    </section>
  );
}
