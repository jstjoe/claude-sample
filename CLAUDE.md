# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A personal collection of Claude Code **tooling and documentation**: skills,
scripts, project config, and GitHub Actions. Its through-line is **automated
demo recording** — turning developer workflows into shareable terminal/browser
demos without a human at the keyboard.

## Layout

```
skills/            Canonical skill library, symlinked into ~/.claude/skills by install.sh
  make-demos/        Front door: bootstrap + route to the recorders + end-to-end recipes
  vhs-demos/         Terminal demos → GIF/MP4 from a .tape script (VHS); + mutate.sh coloring
  playwright-demos/  Browser demos → video/screenshots (Playwright recorder)
  demo-media/        Edit/convert/redact video + images (ffmpeg, ImageMagick)
  remotion-best-practices/  Branded videos in React (Remotion)
docs/
  automated-demos.md  The map: which demo tool to reach for + end-to-end recipes
scripts/
  bootstrap-demos.sh  One-shot install + verify of the whole demo toolchain
.claude/           Project-scoped config for THIS repo (settings, commands, agents, hooks, skills)
install.sh         Symlinks skills into ~/.claude/skills and skill commands onto PATH
package.json       Pins Playwright; `npm install` also fetches Chromium (postinstall)
.github/workflows/ Claude GitHub Actions (PR review + @claude)
```

## Key commands

```bash
./scripts/bootstrap-demos.sh        # install + verify the demo environment (idempotent)
./scripts/bootstrap-demos.sh --check # verify only, install nothing
./install.sh                        # (re)link skills after adding one
npm install                         # Playwright + Chromium
```

## ⭐ "I want to make demos" — bootstrap procedure

This procedure also ships as the portable **`make-demos`** skill (so it triggers
outside this repo). Keep the two in sync when you change the routing.

When a user says they want to **make / record demos** (or record a terminal or
browser walkthrough, a README GIF, a product demo video) and their environment
may not be set up, do this — don't hand them a checklist, run it:

1. **Bootstrap the environment.** Run `./scripts/bootstrap-demos.sh`. It is
   idempotent and self-verifying: it installs VHS (+ttyd+ffmpeg), ImageMagick,
   the JetBrains Mono font, and Playwright+Chromium, links the skills, then
   **smoke-tests** by actually rendering a VHS GIF and recording a Playwright
   video. Relay its final summary.
2. **If it reports failures**, fix the named prerequisite and re-run:
   - No Homebrew → point to https://brew.sh.
   - Node missing or `< 22` → they install Node ≥ 22 (nvm or `brew install node`);
     you don't pick a Node manager for them.
   - A smoke test fails → check the tool it names; re-run `--check` after.
3. **Once green**, ask what they want to demo and route to the right skill:
   - **Terminal / CLI** (commands, a TUI, a README GIF) → **vhs-demos**. A `.tape`
     re-renders identically forever; best default for terminal.
   - **Web app / browser UI** → **playwright-demos**. Author the flow with
     `npx playwright codegen`, then record with `skills/playwright-demos/playwright-record.mjs`.
   - **Editing / converting / redacting** an existing clip → **demo-media**.
   - **Branded intro/titles/motion** around a capture → **remotion-best-practices**.
4. **Point them at [`docs/automated-demos.md`](docs/automated-demos.md)** for the
   decision table and copy-paste recipes, and keep each project's `.tape` /
   `flow.mjs` **in that project's repo** (a tracked `demo/` dir), not here.

The goal: a newcomer points their agent at this repo, says "I want to make
demos," and ends up with a verified toolchain and a first clip — no manual setup.

## Skills: two homes

- **`skills/`** (top level) — the canonical, cross-machine library; `install.sh`
  symlinks it into `~/.claude/skills/`. Edits here go live immediately and git
  tracks them. `remotion-best-practices` is **vendored** upstream — don't
  hand-edit it (see `skills/README.md` for the refresh command).
- **`.claude/skills/`** — skills scoped to this repo only, auto-discovered here.

## Conventions

- **Prefer deterministic over live capture.** VHS `.tape` and Playwright flows
  re-render on demand and stay in sync with the product; reach for a live screen
  recording (demo-media's `record-demo.sh`) only when you need the real desktop.
- **Wait on real signals, not fixed sleeps** (VHS `Wait`, Playwright
  `locator.waitFor()` / `expect(...).toBeVisible()`) — the top cause of flaky recordings.
- **Redact before sharing.** Real tokens/PII in a capture leak even after deletion
  once posted. Blur/fill with demo-media, or Playwright `mask:`, before it leaves the machine.
- **Verify changes to the recorders** by actually recording a short clip, not just
  reading the diff (`scripts/bootstrap-demos.sh --check` re-runs the smoke tests).
- **Personal settings** go in `.claude/settings.local.json` (gitignored), never in
  the committed `.claude/settings.json`.
