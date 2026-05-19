"use client";

import Image from "next/image";
import { AnimatePresence, motion } from "framer-motion";
import { useCallback, useEffect } from "react";
import { ChevronLeft, ChevronRight, X } from "lucide-react";

export type LightboxItem = { src: string; alt?: string };

type LightboxProps = {
  items: LightboxItem[];
  index: number | null;
  onIndexChange: (next: number | null) => void;
};

export function Lightbox({ items, index, onIndexChange }: LightboxProps) {
  const open = index !== null && index >= 0 && index < items.length;
  const current = open ? items[index] : null;
  const count = items.length;

  const close = useCallback(() => onIndexChange(null), [onIndexChange]);
  const next = useCallback(() => {
    if (index === null || count === 0) return;
    onIndexChange((index + 1) % count);
  }, [index, count, onIndexChange]);
  const prev = useCallback(() => {
    if (index === null || count === 0) return;
    onIndexChange((index - 1 + count) % count);
  }, [index, count, onIndexChange]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
      else if (e.key === "ArrowRight") next();
      else if (e.key === "ArrowLeft") prev();
    };
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [open, close, next, prev]);

  const showNav = count > 1;

  return (
    <AnimatePresence>
      {open && current && (
        <motion.div
          key="lightbox-backdrop"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          onClick={close}
          role="dialog"
          aria-modal="true"
          aria-label={current.alt}
          className="fixed inset-0 z-[60] flex items-center justify-center p-4 md:p-10 cursor-zoom-out bg-black/55 backdrop-blur-[6px]"
        >
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              close();
            }}
            aria-label="Close"
            className="absolute top-4 right-4 md:top-6 md:right-6 inline-flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white hover:bg-white/20 transition-colors backdrop-blur-md"
          >
            <X className="h-5 w-5" />
          </button>

          {showNav && (
            <>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  prev();
                }}
                aria-label="Previous image"
                className="absolute left-3 md:left-6 top-1/2 -translate-y-1/2 inline-flex h-11 w-11 md:h-12 md:w-12 items-center justify-center rounded-full bg-white/10 text-white hover:bg-white/20 transition-colors backdrop-blur-md"
              >
                <ChevronLeft className="h-6 w-6" />
              </button>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  next();
                }}
                aria-label="Next image"
                className="absolute right-3 md:right-6 top-1/2 -translate-y-1/2 inline-flex h-11 w-11 md:h-12 md:w-12 items-center justify-center rounded-full bg-white/10 text-white hover:bg-white/20 transition-colors backdrop-blur-md"
              >
                <ChevronRight className="h-6 w-6" />
              </button>
              <div className="absolute bottom-5 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-white/10 text-white text-xs tracking-wide backdrop-blur-md">
                {index! + 1} / {count}
              </div>
            </>
          )}

          <AnimatePresence mode="wait" initial={false}>
            <motion.div
              key={current.src}
              initial={{ scale: 0.94, opacity: 0, y: 10 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.96, opacity: 0, y: 6 }}
              transition={{ type: "spring", stiffness: 280, damping: 28 }}
              onClick={(e) => e.stopPropagation()}
              className="relative w-full max-w-6xl aspect-[16/10] cursor-default"
            >
              <Image
                src={current.src}
                alt={current.alt ?? ""}
                fill
                priority
                sizes="100vw"
                className="object-contain drop-shadow-2xl"
              />
            </motion.div>
          </AnimatePresence>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
