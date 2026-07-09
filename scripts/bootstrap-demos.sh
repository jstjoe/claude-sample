#!/usr/bin/env bash
# bootstrap-demos.sh — install + verify everything needed to record demos from
# this repo: VHS (terminal), Playwright (browser), ffmpeg/ImageMagick (editing),
# the demo font, and the live skills. Idempotent: safe to re-run.
#
#   scripts/bootstrap-demos.sh            # install what's missing, then verify
#   scripts/bootstrap-demos.sh --check    # verify only, install nothing
#   scripts/bootstrap-demos.sh --help
#
# macOS + Homebrew. Node ≥ 22 must already be present (we don't pick a Node
# manager for you). Exits non-zero if any verification fails.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  --help|-h) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "Unknown arg: $1 (see --help)"; exit 2 ;;
esac

# ---- pretty output --------------------------------------------------------
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; X=$'\033[0m'; else G= R= Y= B= X=; fi
ok()   { printf "  ${G}✓${X} %s\n" "$1"; }
bad()  { printf "  ${R}✗${X} %s\n" "$1"; FAILED=$((FAILED+1)); }
info() { printf "  ${Y}•${X} %s\n" "$1"; }
head() { printf "\n${B}%s${X}\n" "$1"; }
FAILED=0

have() { command -v "$1" >/dev/null 2>&1; }

# ---- preflight ------------------------------------------------------------
head "Preflight"
if ! have brew; then
  bad "Homebrew not found. Install from https://brew.sh, then re-run."
  exit 1
fi
ok "Homebrew present"
if ! have node; then
  bad "Node not found. Install Node ≥ 22 (e.g. nvm, or 'brew install node'), then re-run."
  exit 1
fi
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 22 ]; then bad "Node $(node -v) is < 22 — Playwright needs ≥ 22."; else ok "Node $(node -v)"; fi

# ---- install --------------------------------------------------------------
brew_formula() { brew list --formula "$1" >/dev/null 2>&1 || { info "installing $1…"; brew install "$1"; }; }
brew_cask()    { brew list --cask "$1"    >/dev/null 2>&1 || { info "installing $1…"; brew install --cask "$1"; }; }

if [ "$CHECK_ONLY" -eq 0 ]; then
  head "Installing tools (idempotent)"
  brew_formula vhs           # pulls ttyd + ffmpeg as deps
  brew_formula ffmpeg
  brew_formula imagemagick
  brew_cask     font-jetbrains-mono
  ok "Homebrew tools present"

  info "npm install (Playwright + Chromium via postinstall)…"
  ( cd "$REPO_DIR" && npm install ) && ok "npm deps + Chromium installed" || bad "npm install failed"

  info "linking skills (./install.sh)…"
  ( cd "$REPO_DIR" && ./install.sh >/dev/null ) && ok "skills linked into ~/.claude/skills" || bad "install.sh failed"
else
  head "Check-only mode — skipping installs"
fi

# ---- verify presence ------------------------------------------------------
head "Verifying tools"
ver() {                                   # first line of the tool's version, ffmpeg uses -version
  case "$1" in
    ffmpeg) ffmpeg -version 2>/dev/null ;;
    ttyd)   ttyd --version 2>&1 ;;         # ttyd prints version to stderr
    *)      "$1" --version 2>/dev/null ;;
  esac | awk 'NR==1{print substr($0,1,55)}'
}
for bin in vhs ttyd ffmpeg magick node; do
  if have "$bin"; then ok "$bin — $(ver "$bin")"; else bad "$bin missing"; fi
done
if ( cd "$REPO_DIR" && npx --no-install playwright --version >/dev/null 2>&1 ); then
  ok "playwright — $(cd "$REPO_DIR" && npx --no-install playwright --version)"
else
  bad "playwright not installed (run without --check, or: npm install)"
fi
# demo font
if ls "$HOME/Library/Fonts"/JetBrainsMono* >/dev/null 2>&1 || ls /Library/Fonts/JetBrainsMono* >/dev/null 2>&1; then
  ok "JetBrains Mono font installed"
else
  bad "JetBrains Mono font missing (VHS config.tape will fall back)"
fi

# ---- verify it actually records -------------------------------------------
head "Smoke test — record a real clip with each tool"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# VHS: render a tiny tape to a gif
cat > "$TMP/smoke.tape" <<'TAPE'
Output smoke.gif
Set Width 640
Set Height 200
Type "echo bootstrap-ok"
Enter
Sleep 500ms
TAPE
if ( cd "$TMP" && vhs smoke.tape >/dev/null 2>&1 ) && [ -s "$TMP/smoke.gif" ]; then
  ok "VHS rendered a GIF ($(du -h "$TMP/smoke.gif" | cut -f1))"
else
  bad "VHS smoke test failed"
fi

# Playwright: record a tiny headless video via the shipped recorder
cat > "$TMP/flow.mjs" <<'JS'
export default async function demo({ page }) {
  await page.goto('data:text/html,<h1 style="font:40px system-ui">bootstrap ok</h1>', { waitUntil: 'load' });
  await page.waitForTimeout(500);
}
JS
if ( cd "$REPO_DIR" && node skills/playwright-demos/playwright-record.mjs \
      --flow "$TMP/flow.mjs" --out "$TMP/pw" --size 640x400 --slowmo 50 --pause 100 \
      --headless >/dev/null 2>&1 ) && ls "$TMP"/pw/*.webm >/dev/null 2>&1; then
  ok "Playwright recorded a video ($(du -h "$TMP"/pw/*.webm | cut -f1))"
else
  bad "Playwright smoke test failed"
fi

# ---- summary --------------------------------------------------------------
head "Result"
if [ "$FAILED" -eq 0 ]; then
  printf "${G}${B}All good — demo environment is ready.${X}\n"
  printf "Next: read ${B}docs/automated-demos.md${X} — terminal→VHS, browser→Playwright.\n"
  exit 0
else
  printf "${R}${B}%d check(s) failed.${X} Re-run without --check to install, or fix the items above.\n" "$FAILED"
  exit 1
fi
