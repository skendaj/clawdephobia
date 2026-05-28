import { cookies } from "next/headers";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import crypto from "node:crypto";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export const metadata: Metadata = {
  title: "Downloads",
  robots: { index: false, follow: false },
};

type Asset = {
  name: string;
  download_count: number;
};

type Release = {
  tag_name: string;
  name: string | null;
  published_at: string | null;
  assets: Asset[];
};

type ReleaseRow = {
  tag: string;
  published_at: string | null;
  dmgCount: number;
};

async function fetchReleases(): Promise<Release[]> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }
  const res = await fetch(
    "https://api.github.com/repos/skendaj/clawdephobia/releases?per_page=100",
    { headers, cache: "no-store" }
  );
  if (!res.ok) {
    throw new Error(`GitHub API ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

const SESSION_LABEL = "admin_session_v1";

function safeEqual(a: string, b: string) {
  const ab = Buffer.from(a, "utf8");
  const bb = Buffer.from(b, "utf8");
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

function expectedSession(secret: string) {
  return crypto
    .createHmac("sha256", secret)
    .update(SESSION_LABEL)
    .digest("hex");
}

export default async function AdminDownloadsPage() {
  const secret = process.env.ADMIN_TOKEN;
  const jar = await cookies();
  const session = jar.get("admin_session")?.value ?? "";
  if (!secret || !safeEqual(session, expectedSession(secret))) notFound();

  let rows: ReleaseRow[] = [];
  let total = 0;
  let error: string | null = null;

  try {
    const releases = await fetchReleases();
    rows = releases.map((r) => {
      const dmgCount = r.assets
        .filter((a) => a.name.toLowerCase().endsWith(".dmg"))
        .reduce((sum, a) => sum + a.download_count, 0);
      return {
        tag: r.tag_name,
        published_at: r.published_at,
        dmgCount,
      };
    });
    total = rows.reduce((sum, r) => sum + r.dmgCount, 0);
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
  }

  return (
    <main className="min-h-screen bg-cream px-4 py-16 text-ink">
      <div className="mx-auto max-w-2xl">
        <p className="text-[12px] uppercase tracking-[0.18em] text-mute font-semibold">
          Admin
        </p>
        <h1 className="font-display font-bold text-4xl tracking-[-0.03em] mt-1">
          DMG Downloads
        </h1>
        <p className="mt-2 text-[14px] text-mute">
          GitHub Releases asset download counts. Refresh to refetch.
        </p>

        {error ? (
          <div className="mt-8 rounded-xl border border-line bg-cream-2 p-6 text-[14px]">
            <p className="font-semibold">Failed to fetch</p>
            <pre className="mt-2 whitespace-pre-wrap text-mute text-[12px]">
              {error}
            </pre>
          </div>
        ) : (
          <>
            <div className="mt-8 rounded-xl border border-line bg-cream-2 p-6 card-shadow">
              <p className="text-[13px] uppercase tracking-[0.14em] text-mute font-semibold">
                Total
              </p>
              <p className="mt-1 font-display font-bold text-6xl tracking-[-0.03em]">
                {total.toLocaleString()}
              </p>
            </div>

            <div className="mt-8 rounded-xl border border-line bg-cream-2 overflow-hidden">
              <table className="w-full text-[14px]">
                <thead className="bg-ink/5">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold">Tag</th>
                    <th className="text-left px-4 py-3 font-semibold">Published</th>
                    <th className="text-right px-4 py-3 font-semibold">DMG</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <tr key={r.tag} className="border-t border-line">
                      <td className="px-4 py-3 font-mono text-[13px]">{r.tag}</td>
                      <td className="px-4 py-3 text-mute text-[13px]">
                        {r.published_at
                          ? new Date(r.published_at).toLocaleDateString()
                          : "—"}
                      </td>
                      <td className="px-4 py-3 text-right tabular-nums">
                        {r.dmgCount.toLocaleString()}
                      </td>
                    </tr>
                  ))}
                  {rows.length === 0 && (
                    <tr>
                      <td colSpan={3} className="px-4 py-6 text-center text-mute">
                        No releases.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
