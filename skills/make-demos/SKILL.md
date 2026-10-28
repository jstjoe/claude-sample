---
name: make-demos
description: >
  Front door for recording developer demos without a human at the keyboard —
  scripted, reproducible terminal and browser walkthroughs, GIFs, and polished
  videos. Use this to DRIVE the whole pipeline: it sets up the toolchain, then
  routes to the right component skill (vhs-demos for terminal, playwright-demos
  for browser, demo-media for editing/redaction and native-app scenes,
  demo-voiceover for narration, remotion-best-practices for branding) and
  carries the end-to-end recipes. Start here when the user says they want to
  make/record a demo but you don't yet know terminal vs browser, or when a demo
  spans record → edit → narrate → brand. Triggers on: "make a demo", "record a
  demo", "demo video", "product walkthrough", "launch video", "narrated demo",
  "record my terminal / CLI / app", "record a browser demo", "README GIF",
  "screen recording", "demo GIF", "set up demo recording", "I want to make demos".
metadata:
  tags: demo, recording, screencast, gif, video, vhs, playwright, ffmpeg, remotion, pipeline
---

# make-demos — the demo-recording front door

One drivable entry point over four component skills. It answers three questions
in order: **is the environment set up? what are we recording? then what?**

The turnkey scripts and recorders live in the **claude-sample** repo (that's what
`install.sh` linked these skills from). Run the commands below from that checkout.

## 1. Set up the environment (idempotent, self-verifying)

When the user wants to make demos and the machine may not be ready, **run this —
don't hand them a checklist**:

```bash
./scripts/bootstrap-demos.sh          # or the /bootstrap-demos command
```

It installs VHS (+ttyd+ffmpeg), ImageMagick, the JetBrains Mono font, and
Playwright+Chromium, links the skills, then **smoke-tests** by actually rendering
a VHS GIF and recording a Playwright video. `--check` verifies without installing.
Relay its final summary. On failure, fix the named prerequisite and re-run:

- **Requirements:** macOS + Homebrew, and **Node ≥ 22** (Playwright needs it — you
  install Node, the script won't pick a version manager for you).
- No Homebrew → https://brew.sh. Node missing/old → `brew install node` or nvm.
- A smoke test fails → check the tool it names, then `bootstrap-demos.sh --check`.

## 2. Route to the right recorder

| Recording | Skill | Reach for it when |
|---|---|---|
| **Terminal / CLI** → GIF/MP4 from a `.tape` | **vhs-demos** | commands, a TUI, a README GIF — anything terminal that must re-render identically. **Best default for terminal.** |
| **Browser / web UI** → video + screenshots | **playwright-demos** | web-app tours, UI walkthroughs, marketing/docs screenshots |
| **Live macOS desktop** → MP4/GIF | **demo-media** (`record-demo.sh`) | you truly need the real desktop: menus, notifications, multiple apps |
| **A native app showing a file** → MP4 | **demo-media** (native desktop app scenes) | the file an agent fetched should open in Word or another real app |
| **Narration** over a finished cut | **demo-voiceover** | a launch or marketing video needs a voice track |

**Rule of thumb:** *terminal → VHS, browser → Playwright, real desktop → record-demo.sh.*
VHS/Playwright re-render on demand and stay in sync with the product; the live
recorder is the escape hatch.

## 3. Then: edit, colour, redact, brand

- **Edit / convert / redact** a clip → **demo-media** (ffmpeg + ImageMagick): trim,
  crop, speed-up, WebM→MP4, 2-pass palette GIF, annotate, blur/fill PII.
- **Colour on camera** — highlight the important bytes as they record:
  - Terminal (VHS): source **vhs-demos/`mutate.sh`** and pipe `| hi` — raw PII red,
    tokens green (`HL_SENSITIVE`/`HL_TOKENS`), plus `paint` / `redact`.
  - Live capture (record-demo.sh): the same `HL_SENSITIVE`/`HL_TOKENS` env vars.
  - Browser (Playwright): `mask:[locator]` on screenshots; overlays via screencast.
- **Brand it** — intro card, brand colours, titles, transitions → build a
  **remotion-best-practices** composition. Encode a Studio-friendly copy first
  (dense keyframes): `record-demo.sh --remotion` or the ffmpeg one-liner in demo-media.

## End-to-end recipes (the common flows)

```bash
# README GIF for a CLI tool — VHS is the whole pipeline
vhs demo/tour.tape                                   # commit tour.gif next to the README

# Terminal demo with PII coloured red / tokens green — VHS + mutate.sh
#   (tape sources mutate.sh in its Hide block, pipes `| hi`; see demo/colorize.tape)
vhs demo/colorize.tape

# Web-app walkthrough for Slack/docs — Playwright → MP4
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --tag v2

# Polished launch video — Playwright → demo-media → Remotion
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs   # raw .webm
#   → transcode a Studio-friendly copy (demo-media) → build titled Remotion comp → render

# Narrated product video with a real app — Playwright + desktop app + voiceover
#   1. chat or web scene headless with a saved session (playwright-demos)
#   2. Word scenes with screencapture after the person frees the screen (demo-media)
#   3. OCR highlights + push-in + caption bars, cut with ffmpeg (demo-media)
#   4. one eleven_v4 take split per scene, laid over the cut (demo-voiceover)
python3 skills/demo-voiceover/voiceover_take.py demo/narration.json demo-out/audio/v4
```

The October 2026 Skyflow launch video followed the last recipe end to end. Its
project-specific scripts live in the agentcore-skyflow checkout's gitignored
`demo-out/ui-cut-scripts/` directory. The reusable parts are in demo-media and
demo-voiceover.

Full decision table, flag references, and recipes:
**[docs/automated-demos.md](../../docs/automated-demos.md)**. Deep dives live in each
component skill's `SKILL.md`.

## Conventions (carry these into every demo)

- **Deterministic over live.** VHS `.tape` and Playwright flows re-render and stay in
  sync; a one-take screen capture rots. Use the live recorder only when you must.
- **Wait on real signals, not fixed sleeps** — VHS `Wait`, Playwright
  `locator.waitFor()` / `expect(...).toBeVisible()`. The #1 cause of flaky recordings.
- **Redact before sharing.** Real tokens/PII in a capture leak even after deletion
  once posted. Colour-then-`redact` in VHS, `mask:` in Playwright, or blur/fill in
  demo-media — before anything leaves the machine.
- **Keep the demo script in the demoed project.** The `.tape` / `flow.mjs` lives in
  that repo's `demo/` dir; these skills stay generic and reusable.
- **Ask before taking over the screen.** Anything that records the real desktop or
  moves the pointer interrupts the person. Record everything else headless and batch
  the screen takes into one short run once they say the screen is free.
- **Check audio by measurement.** The agent cannot hear the narration. Measure the
  gaps, onsets and loudness (demo-voiceover) and ask the person to listen for named
  words.
- **Cut silent first, narrate second.** Review the picture and the on-screen text as
  a silent cut, then write the narration against its real timings.
