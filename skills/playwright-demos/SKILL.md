---
name: playwright-demos
description: >
  Drive a real browser to produce automated demo videos and screenshots with
  Playwright (local browser automation, macOS). Use when the user wants to
  record a scripted web-app walkthrough to video/GIF/MP4, capture screenshots of
  a site or flow, auto-generate an automation script from clicks
  (codegen), emulate a device, or build a repeatable browser-demo pipeline.
  Ships a turnkey recorder (playwright-record.mjs) that launches Chromium,
  records the session with an animated cursor + action/chapter overlays via the
  screencast API, runs a scripted flow you supply, and emits a timestamped
  webm/mp4/gif + PNG stills. Triggers on: "record a browser demo", "Playwright",
  "playwright-record", "screencast", "codegen", "record web app", "browser
  screenshot", "automate the browser", "screen record a website", "demo a web UI".
metadata:
  tags: playwright, browser, video, screencast, screenshots, demo, automation
---

# Playwright demos: scripted browser recordings

Local browser automation tuned for **demo capture** — record a web-app
walkthrough to video, grab screenshots, or author the script by clicking. Pairs
with the sibling **demo-media** (ffmpeg/ImageMagick edits) and
**remotion-best-practices** (branded titles/motion) skills.

Verified against **Playwright 1.61**. Requires **Node ≥ 22**.

## Setup

Playwright is already wired into this repo's `package.json`. From the repo root:

```bash
pnpm install                      # installs playwright + (postinstall) Chromium
# or, in another project:
pnpm add -D playwright && pnpm exec playwright install chromium
```

The playwright package and the browser binaries are **separate installs** — `pnpm add`
alone does not download a browser. Browsers cache in `~/Library/Caches/ms-playwright`
(override with `PLAYWRIGHT_BROWSERS_PATH`). On CI add `--with-deps`.

## Turnkey recorder: `playwright-record.mjs`

This skill ships a recorder — `playwright-record.mjs`, in this skill's directory.
It launches Chromium (headed, paced with `slowMo` so it reads on camera), records
the session, runs a **scripted flow you supply**, flushes the video, and
optionally transcodes to a shareable **MP4** and a snappy **GIF**. One command,
walk away — the browser twin of demo-media's `record-demo.sh` terminal recorder.

```bash
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --gif
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --device "iPhone 15" --mp4
node skills/playwright-demos/playwright-record.mjs --url https://example.com --shot hero.png   # screenshot only
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --headless             # CI / no window
node skills/playwright-demos/playwright-record.mjs --help
```

By default it records with Playwright's **screencast** API (per-action **title
overlays** + full-screen **chapter cards**) and injects an **always-visible
cursor** — an arrow that follows the mouse with a smooth glide and a click pulse,
so an automated run reads as narrated. `--basic` falls back to the plain
`recordVideo` context option (no overlays/cursor). Outputs land in
`demo-out/<stamp>[-tag].{webm,mp4,gif}` and `demo-out/<stamp>-<name>.png` — never
overwriting a prior take.

Key flags (full list via `--help`): `--size WxH` (viewport + video), `--slowmo ms`
(pacing between actions), `--pause ms` (hold after each step), `--hold ms` (how long
title labels linger), `--device NAME` (emulation), `--cursor pointer|none` (the
injected cursor; `none` hides it), `--scale 2` (retina screenshots), `--headless`,
`--tag LABEL`, `--mp4`, `--gif`, `--no-webm`.

### The flow file (`--flow`)

A small ES module that default-exports an async function. The recorder calls it
with a context object and drives pacing + on-screen narration:

```js
export default async function demo({ page, step, chapter, shot, move, log, args }) {
  await page.goto(args.url ?? 'http://localhost:3000', { waitUntil: 'networkidle' });
  await chapter('Widget Console', { description: 'Search, browse, drill in' });   // full-screen card
  await step('Search for widgets', async () => {
    const q = page.getByPlaceholder('Search');
    await move(q);                                   // glide the cursor over, then act
    await q.fill('widgets');
    await page.getByRole('button', { name: 'Search' }).click();
    await page.getByText(/results/i).waitFor();      // wait on a real signal, not a fixed sleep
  });
  await shot('results');   // demo-out/<stamp>-results.png, a still for docs/Slack
}
```

- `page`, `context` — Playwright objects; the video is already recording.
- `step(label, fn)` — runs `fn`, logs the label, holds `--pause` after.
- `chapter(title, {description, duration})` — full-screen narration card (screencast only).
- `move(locator | {x,y})` — glide the injected cursor to an element so its travel is
  visible on camera; `.hover()`/`.click()` also move it. The click pulse fires as the
  cursor lands. Author flows so the pointer visibly travels — that's what reads as a demo.
- `shot(name)` — timestamped PNG still alongside the video.
- Full template: **`flow.example.mjs`** beside this script. Keep each project's
  flow file *in that project's repo* (e.g. a tracked `demo/` dir), not here.

Design decisions worth keeping:

- **Screencast by default, recordVideo as fallback.** Screencast (Playwright ≥1.59)
  gives action titles + chapter cards and writes straight to our timestamped path.
  `--basic` uses `recordVideo`, whose file is random-named and flushed only on
  `context.close()` — the recorder renames it for you either way.
- **Injected cursor, not the native one.** The recorder injects its own always-visible
  cursor (arrow + CSS glide + click pulse) instead of screencast's native pointer. The
  native pointer only appears at discrete actions (so it reads as teleporting) and its
  red click marker fires at the true point *ahead* of a gliding cursor. The injected one
  follows the mouse continuously and its pulse is delayed to bloom as the cursor lands.
  Works headless too (it's just DOM) — so a `--headless` CI recording still shows a cursor.
- **Headed + `slowMo` by default.** `slowMo` inserts delay around every action so it's
  watchable; headed also shows real OS chrome. `--headless` still records fine for CI.
- **Video is WebM only.** Sharing needs MP4/GIF, so `--mp4`/`--gif` transcode with
  the same ffmpeg recipes as demo-media (H.264 `-pix_fmt yuv420p -movflags +faststart`;
  2-pass palette GIF). Video flushes on `stop()`/`context.close()` — read the path after.

## Author flows by recording: `codegen`

Don't hand-write selectors — **click through the flow and let Playwright emit the
script**, then paste the locators into your flow file:

```bash
pnpm exec playwright codegen http://localhost:3000
pnpm exec playwright codegen --viewport-size="1280,800" --output demo/raw.mjs http://localhost:3000
pnpm exec playwright codegen --device="iPhone 15" example.com
```

Auth-gated apps: record once saving storage, then replay it:

```bash
pnpm exec playwright codegen --save-storage=auth.json https://app.example.com/login   # log in, close
pnpm exec playwright codegen --load-storage=auth.json  https://app.example.com        # already signed in
# in a flow: await browser.newContext({ storageState: 'auth.json' })
```

codegen prefers **role/text/label/test-id** locators (`getByRole`, `getByText`,
`getByLabel`, `getByTestId`) — keep those over brittle CSS; they read clearly on
camera and survive restyles.

## Screenshots

```bash
node skills/playwright-demos/playwright-record.mjs --url https://example.com --shot hero.png --scale 2
pnpm exec playwright screenshot --full-page https://example.com out.png
pnpm exec playwright screenshot --device="iPhone 15" --color-scheme=dark example.com mobile.png
```

In a flow: `await page.screenshot({ path, fullPage })`, element shots via
`locator.screenshot()`, crop with `clip:{x,y,width,height}`, box out secrets with
`mask:[locator]`. **Retina** needs two settings together: context
`deviceScaleFactor: 2` **and** screenshot `scale: 'device'` (default `'css'` ignores DPR).
The recorder wires this up when you pass `--scale 2`.

## Pacing that reads on camera

- **`slowMo`** (launch option, ms) is the primary knob — delays every action. The
  recorder sets it from `--slowmo`.
- **Wait on real signals**, not fixed sleeps: `await expect(locator).toBeVisible()`,
  `page.waitForLoadState('networkidle')`, `locator.waitFor()`. `page.waitForTimeout`
  is acceptable for demo beats but is an anti-pattern for correctness.
- **Make the cursor travel.** The injected cursor + action titles come free, but they
  only read as a demo if the pointer visibly moves — use `move(locator)` and `.hover()`
  to glide it and surface hover states before each click, rather than jumping click to
  click. For custom callouts use `page.screencast.showOverlay('<div>…</div>', {duration})`
  or annotate in post with demo-media/Remotion.

## → Editing & branding

- Trim/crop/speed/compress, or convert WebM→MP4/GIF by hand: use **demo-media**.
- Wrap the recording in an intro card, brand colors, and transitions: **remotion-best-practices**
  (encode a Studio-friendly copy first — see demo-media's `--remotion`).

## Gotchas

- **Browsers install separately** from the playwright package — run `pnpm exec playwright install chromium`.
- **Video flushes late**: `page.screencast.stop()` or `context.close()` writes the
  file; read `page.video().path()` *after* close (the recorder handles this).
- **Default video size is capped** to an 800×800 box if you don't set `size` — the
  recorder always sets it from `--size`.
- **WebM only** out of Playwright; transcode for sharing.
- **`page.video()` is `null`** unless the context enabled recording; one video **per page**.
- **Trace viewer** (`context.tracing.start(...)` → `pnpm exec playwright show-trace trace.zip`)
  is for *debugging* a flow (DOM/network/timeline), not a clean demo asset.
