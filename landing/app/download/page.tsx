import Image from "next/image";
import Link from "next/link";
import Script from "next/script";
import { Github, FileText } from "lucide-react";
import { ApplePlain } from "@/components/icons/apple-plain";
import { Nav } from "@/components/nav";
import { Footer } from "@/components/footer";
import { Highlight } from "@/components/highlight";
import { Button } from "@/components/ui/button";
import { breadcrumbJsonLd } from "@/lib/breadcrumb";
import type { Metadata } from "next";

const breadcrumbLd = breadcrumbJsonLd([
  { name: "Home", path: "/" },
  { name: "Download", path: "/download" },
]);

const DOWNLOAD_URL =
  "https://github.com/skendaj/clawdephobia/releases/latest/download/Clawdephobia.dmg";
const REPO_URL = "https://github.com/skendaj/clawdephobia";
const APP_STORE_URL =
  "https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12";

export const metadata: Metadata = {
  title: "Download — Clawdephobia",
  description:
    "Download Clawdephobia for macOS 13+. Free, open-source, signed and notarized. Drag-to-Applications install from GitHub Releases.",
  alternates: { canonical: "/download" },
  openGraph: {
    title: "Download Clawdephobia for Mac",
    description:
      "Free, open-source macOS menu bar app for Claude usage limits. Signed, notarized, drag-to-install.",
    type: "website",
    url: "/download",
    siteName: "Clawdephobia",
  },
  twitter: {
    card: "summary_large_image",
    title: "Download Clawdephobia for Mac",
    description:
      "Free, open-source macOS menu bar app for Claude usage limits.",
  },
};

async function getLatestVersion(): Promise<string> {
  try {
    const res = await fetch(
      "https://api.github.com/repos/skendaj/clawdephobia/releases/latest",
      { next: { revalidate: 3600 } }
    );
    if (!res.ok) return "";
    const data = await res.json();
    return (data.tag_name as string) ?? "";
  } catch {
    return "";
  }
}

export default async function DownloadPage() {
  const version = await getLatestVersion();
  return (
    <main className="min-h-screen">
      <script
        type="application/ld+json"
        suppressHydrationWarning
      >{JSON.stringify(breadcrumbLd)}</script>
      <Nav />
      <section className="px-4 pt-36 md:pt-44 pb-20 text-center">
        <h1 className="font-display font-bold tracking-[-0.03em] text-[48px] sm:text-[64px] md:text-[84px] leading-[0.98]">
          Download Clawdephobia
          <br />
          for <Highlight>Mac</Highlight>
        </h1>
        <p className="mt-6 max-w-xl mx-auto text-[15px] md:text-[16px] text-graphite/85 leading-relaxed">
          Once downloaded, open the DMG and drag{" "}
          <span className="inline-flex items-center gap-1">
            <Image
              src="/icon.png"
              alt=""
              width={18}
              height={18}
              className="inline-block rounded-[4px]"
            />
            <strong className="font-semibold">Clawdephobia</strong>
          </span>{" "}
          to your Applications folder{" "}
          <em className="italic">before</em> launching it.
        </p>

        <div className="mt-12 mx-auto grid max-w-3xl gap-5 sm:grid-cols-2">
          <a
            href={DOWNLOAD_URL}
            className="group relative flex flex-col items-center rounded-[var(--radius-card)] border border-line bg-cream-2 p-8 card-shadow transition-transform duration-300 hover:-translate-y-1"
          >
            <div className="h-24 w-24 rounded-[20px] bg-white border border-line flex items-center justify-center mb-5 overflow-hidden">
              <Image
                src="/icon.png"
                alt="Clawdephobia"
                width={80}
                height={80}
                className="object-cover"
              />
            </div>
            <p className="font-display font-semibold text-lg">Clawdephobia</p>
            <p className="mt-1 text-[13px] text-mute">
              Minimum macOS 13 Ventura
            </p>
            <p className="text-[13px] text-mute">DMG{version ? ` · ${version}` : ""} · GitHub release</p>
            <div className="mt-5">
              <Button asChild>
                <span>
                  <Github className="h-4 w-4" />
                  Download from GitHub
                </span>
              </Button>
            </div>
          </a>

          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="group relative flex flex-col items-center rounded-[var(--radius-card)] border border-line bg-cream-2 p-8 card-shadow transition-transform duration-300 hover:-translate-y-1"
          >
            <div className="h-24 w-24 rounded-[20px] bg-white border border-line flex items-center justify-center mb-5">
              <ApplePlain className="h-10 w-10" />
            </div>
            <p className="font-display font-semibold text-lg">Mac App Store</p>
            <p className="mt-1 text-[13px] text-mute">One-click install</p>
            <p className="text-[13px] text-mute">Automatic updates</p>
            <div className="mt-5">
              <Button asChild>
                <span>
                  <ApplePlain className="h-4 w-4" />
                  Get from App Store
                </span>
              </Button>
            </div>
          </a>
        </div>

        <div className="mt-16 max-w-2xl mx-auto text-left">
          <p className="flex items-center gap-2 text-[12px] uppercase tracking-[0.18em] text-mute font-semibold">
            <FileText className="h-3.5 w-3.5" />
            How to install
          </p>
          <ol className="mt-4 space-y-3 text-[15px] text-graphite/90 leading-relaxed">
            <li>
              <strong>1.</strong> Download the DMG from{" "}
              <a
                href={REPO_URL + "/releases"}
                target="_blank"
                rel="noreferrer"
                className="underline-offset-2 hover:underline"
              >
                Releases
              </a>
              .
            </li>
            <li>
              <strong>2.</strong> Open it and drag Clawdephobia.app to{" "}
              <code className="px-1.5 py-0.5 rounded bg-ink/5 text-[13px]">
                /Applications
              </code>
              .
            </li>
            <li>
              <strong>3.</strong> Right-click → <strong>Open</strong> on first
              launch to clear Gatekeeper. After that, launch normally.
            </li>
          </ol>
          <p className="mt-8 text-center text-[12.5px] text-mute">
            Signed and notarized by Apple. Need your session key?{" "}
            <Link
              href="/faqs"
              className="underline-offset-2 hover:underline text-graphite"
            >
              Read the FAQs →
            </Link>
          </p>
        </div>
      </section>
      <Footer />
    </main>
  );
}
