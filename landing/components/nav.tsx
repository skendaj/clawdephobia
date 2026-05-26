"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { HelpCircle, Home } from "lucide-react";
import { ApplePlain } from "@/components/icons/apple-plain";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { DownloadModal } from "@/components/download-modal";

const VERSION = "v1.0";

export function Nav({ dark = false }: { dark?: boolean }) {
  const [scrolled, setScrolled] = useState(false);
  const [downloadOpen, setDownloadOpen] = useState(false);
  const pathname = usePathname();
  const isHome = pathname === "/";
  const secondaryHref = isHome ? "/faqs" : "/";
  const secondaryLabel = isHome ? "FAQs" : "Home";
  const SecondaryIcon = isHome ? HelpCircle : Home;
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <>
      <DownloadModal open={downloadOpen} onClose={() => setDownloadOpen(false)} />
      <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 flex items-center justify-between px-4 md:px-8 py-3",
        "border-b border-transparent transition-[background-color,backdrop-filter,border-color] duration-300 ease-out",
        scrolled && "backdrop-blur-xl",
        scrolled && !dark && "bg-cream/70 border-line",
        scrolled && dark && "bg-night/70 border-white/5"
      )}
    >
      <Link href="/" className="flex items-center gap-2 group">
        <span className="relative inline-flex">
          <span
            className={cn(
              "scared inline-flex h-9 w-9 items-center justify-center rounded-[10px] overflow-hidden border will-change-transform",
              dark ? "border-white/10 bg-white/5" : "border-line bg-cream-2"
            )}
          >
            <Image
              src="/icon.png"
              alt="Clawdephobia"
              width={36}
              height={36}
              className="h-9 w-9 object-cover"
              priority
            />
          </span>
          <span
            aria-hidden
            className={cn(
              "speech-bubble pointer-events-none absolute left-1/2 top-full mt-2.5 opacity-0 transition-opacity duration-200 ease-out group-hover:opacity-100",
              "whitespace-nowrap rounded-xl px-3 py-1.5 text-[12px] font-semibold tracking-tight",
              dark
                ? "bg-cream text-ink shadow-[0_10px_30px_-10px_rgba(0,0,0,0.6)]"
                : "bg-ink text-cream shadow-[0_10px_30px_-10px_rgba(31,30,29,0.45)]"
            )}
          >
            i&apos;m scared!
          </span>
        </span>
        <span
          className={cn(
            "font-display font-semibold tracking-tight text-[17px]",
            dark && "text-cream"
          )}
        >
          Clawdephobia
        </span>
        <Badge
          className={cn(
            dark && "border-white/10 bg-white/5 text-cream/70"
          )}
        >
          {VERSION}
        </Badge>
      </Link>

      <nav className="flex items-center gap-1 md:gap-2">
        <Link
          href={secondaryHref}
          aria-label={secondaryLabel}
          className={cn(
            "inline-flex items-center gap-2 rounded-full transition-colors",
            "h-9 w-9 sm:h-auto sm:w-auto sm:px-4 sm:py-2 justify-center text-sm font-medium",
            dark
              ? "text-cream/80 hover:bg-white/5 border border-white/10 sm:border-0"
              : "text-graphite hover:bg-ink/5 border border-line sm:border-0"
          )}
        >
          <SecondaryIcon className="h-4 w-4 sm:hidden" />
          <span className="hidden sm:inline">{secondaryLabel}</span>
        </Link>
        <Button size="default" onClick={() => setDownloadOpen(true)}>
          <ApplePlain className="h-4 w-4" />
          <span className="hidden xs:inline">Download for Mac</span>
          <span className="xs:hidden">Download</span>
        </Button>
      </nav>
    </header>
    </>
  );
}
