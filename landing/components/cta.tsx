import { Github } from "lucide-react";
import { ApplePlain } from "@/components/icons/apple-plain";
import { Button } from "@/components/ui/button";

const DOWNLOAD_URL =
  "https://github.com/skendaj/clawdephobia/releases/latest/download/Clawdephobia.dmg";
const REPO_URL = "https://github.com/skendaj/clawdephobia";
const APP_STORE_URL =
  "https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12";

export function CTA() {
  return (
    <section className="px-4 pt-10 pb-24 md:pb-32 text-center">
      <h2 className="font-display font-bold tracking-[-0.03em] text-4xl md:text-6xl">
        Stop guessing your limits.
      </h2>
      <p className="mt-4 text-graphite/80 max-w-md mx-auto text-[15px] md:text-[16px]">
        Free, open source, and built for people who live in Claude.
      </p>
      <div className="mt-8 flex items-center justify-center gap-3 flex-wrap">
        <Button asChild size="lg" variant="soft">
          <a href={APP_STORE_URL} target="_blank" rel="noreferrer">
            <ApplePlain className="h-4 w-4" />
            Mac App Store
          </a>
        </Button>
        <Button asChild size="lg">
          <a href={DOWNLOAD_URL}>
            <Github className="h-4 w-4" />
            Download DMG
          </a>
        </Button>
        <Button asChild size="lg" variant="ghost">
          <a href={REPO_URL} target="_blank" rel="noreferrer">
            <Github className="h-4 w-4" />
            Star on GitHub
          </a>
        </Button>
      </div>
    </section>
  );
}
