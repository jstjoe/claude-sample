---
description: Install + verify the demo-recording toolchain (VHS, Playwright, ffmpeg, ImageMagick)
argument-hint: "[--check]"
allowed-tools: Bash(./scripts/bootstrap-demos.sh:*), Bash(scripts/bootstrap-demos.sh:*)
---
Bootstrap this machine's demo-recording environment.

Run the repo's bootstrap script (idempotent; installs what's missing, then
smoke-tests by rendering a real VHS GIF and a Playwright video):

!`./scripts/bootstrap-demos.sh $ARGUMENTS`

Then:
- Relay the script's summary.
- If any check failed, help fix the named prerequisite (Homebrew, Node ≥ 22, or
  the specific tool) and re-run.
- If all green, point me at `docs/automated-demos.md` and ask what I want to
  demo, then route me to the right skill (terminal → vhs-demos, browser →
  playwright-demos, editing → demo-media, branding → remotion-best-practices).
