# Automated demo recordings

A practical guide to recording developer demos **without a human at the
keyboard** — scripted, reproducible, and re-runnable when the product changes.

This repo ships four skills that cover the whole pipeline. This guide is the map:
what each one is for, how they fit together, and copy-paste recipes for the common
end-to-end flows.

| Skill | Records / does | Reach for it when |
|---|---|---|
| **[vhs-demos](../skills/vhs-demos/)** | **Terminal** sessions → GIF/MP4/WebM, from a `.tape` script | CLI walkthroughs, README GIFs, anything terminal that must re-render identically |
| **[playwright-demos](../skills/playwright-demos/)** | **Browser** sessions → WebM (+MP4/GIF), from a scripted flow; screenshots | Web-app tours, UI walkthroughs, marketing/docs screenshots |
| **[demo-media](../skills/demo-media/)** | **Edits** video/images with ffmpeg + ImageMagick; a live-screen recorder | Trim/crop/speed/compress, convert WebM→MP4/GIF, annotate, **redact PII** |
| **[remotion-best-practices](../skills/remotion-best-practices/)** | **Brands** a recording in React → titled MP4 | Intro cards, brand colors, captions, transitions around a raw capture |

**Rule of thumb:** *terminal → VHS, browser → Playwright.* Both emit a shareable
clip on their own. Send it through **demo-media** to polish or redact, and through
**Remotion** to add titles and motion.

There's also demo-media's `record-demo.sh` — a **live macOS screen recorder** that
drives a scripted terminal demo on camera. Use it when you need a real desktop
capture (menus, notifications, multiple apps); use **VHS** when you want a clean,
deterministic terminal render that never drifts. VHS is the better default for
terminal demos; `record-demo.sh` is the escape hatch for "record my actual screen".

## Install everything (one time)

```bash
# Terminal demos — VHS (+ its ttyd/ffmpeg deps) and the demo font
brew install vhs
brew install --cask font-jetbrains-mono

# Browser demos — Playwright + Chromium (from this repo root)
npm install                 # installs playwright and, via postinstall, the Chromium browser

# Editing — ffmpeg + ImageMagick (demo-media)
brew install ffmpeg imagemagick

# Make the skills live for Claude Code
./install.sh
```

Verify: `vhs --version`, `npx playwright --version`, `ffmpeg -version | head -1`,
`magick -version | head -1`.

## Terminal demo (VHS) — quickstart

VHS types your keystrokes into a headless terminal and encodes the frames, so the
same `.tape` produces the same GIF every time.

```bash
cp skills/vhs-demos/{config.tape,demo.example.tape} demo/    # into your project
$EDITOR demo/demo.example.tape                                # edit the Type lines
vhs demo/demo.example.tape                                    # → demo.gif + demo.mp4
```

Skeleton (`Source` shared settings, hide setup, wait on real output):

```tape
Output tour.gif
Source config.tape
Hide
Type "export PS1='$ '" Enter
Type "clear" Enter
Show
Type "mytool build" Enter
Wait+Screen /Done/          # wait for real output, not a fixed Sleep
Sleep 1s
```

Full command + `.tape` reference: **[skills/vhs-demos/SKILL.md](../skills/vhs-demos/SKILL.md)**.

## Browser demo (Playwright) — quickstart

The recorder launches Chromium, records with an animated cursor + action/chapter
overlays (the screencast API), runs a flow you supply, and emits a timestamped
clip + stills.

```bash
# 1. author the flow by clicking through it — paste the locators it prints
npx playwright codegen http://localhost:3000

# 2. drop them into a flow module (template beside the recorder)
cp skills/playwright-demos/flow.example.mjs demo/flow.mjs
$EDITOR demo/flow.mjs

# 3. record → demo-out/<stamp>.{webm,mp4,gif} + PNG stills
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --gif
```

A flow is just an async function that gets `page`, `step`, `chapter`, `shot`:

```js
export default async function demo({ page, step, chapter, shot, args }) {
  await page.goto(args.url ?? 'http://localhost:3000', { waitUntil: 'networkidle' });
  await chapter('Widget Console', { description: 'Search & drill in' });
  await step('Search', async () => {
    await page.getByPlaceholder('Search').fill('widgets');
    await page.keyboard.press('Enter');
    await page.getByText(/results/i).waitFor();
  });
  await shot('results');
}
```

Screenshot-only, no video: `--url <url> --shot hero.png`. Full flag + API
reference: **[skills/playwright-demos/SKILL.md](../skills/playwright-demos/SKILL.md)**.

## Edit / convert / redact (demo-media)

Both recorders lean on the same ffmpeg recipes demo-media documents. Reach for it
directly for one-offs:

```bash
# WebM (Playwright) → shareable MP4
ffmpeg -i demo.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart demo.mp4

# any clip → clean GIF (2-pass palette)
ffmpeg -i in.mov -vf "fps=12,scale=1000:-1:flags=lanczos,palettegen" pal.png
ffmpeg -i in.mov -i pal.png -lavfi "fps=12,scale=1000:-1:flags=lanczos,paletteuse" out.gif

# redact a secret in a screenshot before sharing (hard fill, unrecoverable)
magick shot.png -fill black -draw "rectangle 300,220 700,260" safe.png
```

The recorders' `--mp4`/`--gif` flags run these for you. See
**[skills/demo-media/SKILL.md](../skills/demo-media/SKILL.md)** for trimming,
cropping, speed-ups, annotation, and batch screenshot cleanup.

## Brand it (Remotion)

To wrap a raw capture in an intro card, brand colors, and transitions, build a
Remotion composition and drop the recording into `public/`. Encode a
Studio-friendly copy first (dense keyframes) — demo-media's `record-demo.sh --remotion`
or the equivalent ffmpeg one-liner. See
**[skills/remotion-best-practices/SKILL.md](../skills/remotion-best-practices/SKILL.md)**.

## End-to-end recipes

**README GIF for a CLI tool** — VHS is the whole pipeline:
```bash
vhs demo/tour.tape        # Output tour.gif; commit it next to the README
```

**Web-app walkthrough for Slack/docs** — Playwright → share the MP4:
```bash
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --tag v2
# → demo-out/<stamp>-v2.mp4 (drag into Slack) + <stamp>-v2-*.png stills
```

**Polished launch video** — Playwright → demo-media → Remotion:
```bash
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs   # raw .webm
ffmpeg -i demo-out/<stamp>.webm -vf "scale=-2:1080:flags=lanczos" \
  -c:v libx264 -crf 20 -g 15 -keyint_min 15 -sc_threshold 0 \
  -pix_fmt yuv420p -movflags +faststart public/demo.mp4                   # Studio-friendly copy
# then build the titled composition in Remotion and render to MP4
```

**Retina screenshots for docs** — Playwright, no video:
```bash
node skills/playwright-demos/playwright-record.mjs --url https://app.local --shot hero.png --scale 2
```

## Principles

- **Prefer deterministic over live.** VHS `.tape` and Playwright flows re-render on
  demand and stay in sync with the product; a one-take screen capture rots. Use the
  live recorder (`record-demo.sh`) only when you truly need the real desktop.
- **Wait on real signals, not fixed sleeps.** VHS `Wait`, Playwright
  `expect(...).toBeVisible()` / `locator.waitFor()`. Fixed sleeps are the #1 source
  of flaky recordings.
- **Redact before you share.** Real tokens/PII in a capture are a leak even after
  deletion once posted. Blur/fill with demo-media, or Playwright `mask:` on
  screenshots, before anything leaves your machine.
- **Keep the demo script in the demoed project.** The `.tape` / `flow.mjs` lives in
  that repo's `demo/` dir; these skills stay generic and reusable across projects.
