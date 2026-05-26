# Clawdephobia — Landing

Marketing site for [Clawdephobia](https://github.com/skendaj/clawdephobia). Next.js 15 (App Router) + Tailwind v4 + shadcn-style primitives. Smooth scroll via Lenis, animations via Framer Motion, hero 3D scene via React Three Fiber.

## Develop

```bash
pnpm install
pnpm dev          # http://localhost:3000
```

## Deploy

Hosted on Vercel. **Root Directory = `landing`** in the Vercel project settings. Framework preset auto-detects Next.js. No env vars required.

```
landing/
├── app/                  # /, /faqs, /download
├── components/           # nav, hero, hero-scene (R3F), feature-grid, …
├── public/
│   ├── icon.png          # mirrored from ../Resources/icon.png
│   └── shots/            # popover, setup, settings screenshots
└── lib/utils.ts
```

## Updating screenshots

Copy fresh PNGs into `public/shots/` (keep the same filenames). They are referenced from `components/product-card.tsx` and `components/walkthrough.tsx`.

## Linking back to the app

Every download button targets the latest GitHub release asset:

```
https://github.com/skendaj/clawdephobia/releases/latest/download/Clawdephobia.dmg
```

The Mac App Store build is live at [apps.apple.com/us/app/clawdephobia-track-usage/id6761192797](https://apps.apple.com/us/app/clawdephobia-track-usage/id6761192797?mt=12).
