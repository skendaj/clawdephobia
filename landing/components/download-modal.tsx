"use client";

import { X, ExternalLink } from "lucide-react";
import { useEffect } from "react";
import { ApplePlain } from "@/components/icons/apple-plain";
import { Github } from "lucide-react";

const APP_STORE_URL =
  "https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12";
const GITHUB_URL =
  "https://github.com/skendaj/clawdephobia/releases/latest/download/Clawdephobia.dmg";

export function DownloadModal({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [open, onClose]);

  useEffect(() => {
    if (open) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" />

      <div
        onClick={(e) => e.stopPropagation()}
        className="relative w-full max-w-sm rounded-[var(--radius-card)] bg-cream p-8 card-shadow animate-in fade-in zoom-in"
      >
        <button
          onClick={onClose}
          className="absolute top-4 right-4 h-8 w-8 rounded-full flex items-center justify-center text-mute hover:text-ink hover:bg-ink/5 transition-colors"
          aria-label="Close"
        >
          <X className="h-4 w-4" />
        </button>

        <h2 className="font-display font-bold text-2xl tracking-[-0.03em]">
          Download Clawdephobia
        </h2>
        <p className="mt-1 text-[14px] text-mute">
          Choose your preferred way to install.
        </p>

        <div className="mt-6 space-y-3">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-4 rounded-xl bg-pill text-cream p-4 pill-shadow hover:scale-[1.02] active:scale-[0.98] transition-all duration-300 ease-out"
          >
            <ApplePlain className="h-6 w-6 shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[15px]">Mac App Store</p>
              <p className="text-[12px] text-cream/70">
                One-click install &middot; Auto-updates
              </p>
            </div>
            <ExternalLink className="h-4 w-4 shrink-0 text-cream/50" />
          </a>

          <a
            href={GITHUB_URL}
            className="flex items-center gap-4 rounded-xl border border-line bg-cream-2 p-4 hover:bg-white hover:scale-[1.02] active:scale-[0.98] transition-all duration-300 ease-out group"
          >
            <Github className="h-6 w-6 shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[15px]">Download DMG</p>
              <p className="text-[12px] text-mute">
                GitHub release &middot; Drag to Applications
              </p>
            </div>
            <ExternalLink className="h-4 w-4 shrink-0 text-mute/30 group-hover:text-mute/60 transition-colors" />
          </a>
        </div>

        <div className="mt-4 text-center">
          <a
            href="https://github.com/skendaj/clawdephobia"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 rounded-full border border-line bg-cream-2 px-2.5 py-1 text-[11px] font-medium text-mute hover:text-ink hover:bg-white transition-colors"
          >
            <Github className="h-3 w-3" />
            Star on GitHub
          </a>
        </div>

        <p className="mt-3 text-center text-[11px] text-mute">
          Free &middot; Open source &middot; macOS 13+
        </p>
      </div>
    </div>
  );
}
