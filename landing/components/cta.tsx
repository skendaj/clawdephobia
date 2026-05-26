"use client";

import { useState } from "react";
import { Github } from "lucide-react";
import { ApplePlain } from "@/components/icons/apple-plain";
import { Button } from "@/components/ui/button";
import { DownloadModal } from "@/components/download-modal";

const REPO_URL = "https://github.com/skendaj/clawdephobia";

export function CTA() {
  const [downloadOpen, setDownloadOpen] = useState(false);

  return (
    <>
      <DownloadModal open={downloadOpen} onClose={() => setDownloadOpen(false)} />
      <section className="px-4 pt-10 pb-24 md:pb-32 text-center">
        <h2 className="font-display font-bold tracking-[-0.03em] text-4xl md:text-6xl">
          Stop guessing your limits.
        </h2>
        <p className="mt-4 text-graphite/80 max-w-md mx-auto text-[15px] md:text-[16px]">
          Free, open source, and built for people who live in Claude.
        </p>
        <div className="mt-8 flex items-center justify-center gap-3 flex-wrap">
          <Button size="lg" onClick={() => setDownloadOpen(true)}>
            <ApplePlain className="h-4 w-4" />
            Download for Mac
          </Button>
          <Button asChild size="lg" variant="ghost">
            <a href={REPO_URL} target="_blank" rel="noreferrer">
              <Github className="h-4 w-4" />
              Star on GitHub
            </a>
          </Button>
        </div>
      </section>
    </>
  );
}
