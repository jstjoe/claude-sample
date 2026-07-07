#!/usr/bin/env bash
# record-demo.sh — self-driving demo recorder. Starts a screen recording, runs
# a scripted demo (labeled + paced so it reads on camera), stops the recording,
# and emits BOTH an editable MP4 (real-time, for a talk track later) and a snappy
# GIF (sped up, for inline docs/Slack). macOS only (ffmpeg avfoundation).
#
# Pairs with the demo-media skill. Run ONE command and walk away. Project-agnostic:
# the demo it runs comes from a --steps file, so the script itself is reusable.
#
# Demo steps (--steps FILE):
#   The recorder is driven by a small shell file you provide. It sets DEMO_TITLE
#   and defines a demo() function that calls  step "<label>" "<command>"  once per
#   on-camera command. Example: demo-steps.example.sh (shipped beside this script).
#   If --steps is omitted, ./demo-steps.sh then ./demo/steps.sh are auto-detected.
#   step(), the pacing (PAUSE_*), and colors are provided by the recorder; the
#   file may also read env like INCLUDE_LIVE to conditionally include steps.
#
# Screen selection:
#   - Pass --screen N (avfoundation index) or --screen-name "Capture screen 1".
#   - Otherwise: 1 screen -> used automatically; >1 screen -> you're prompted to pick.
#   avfoundation indices reorder when cameras/mics are (un)plugged, so we resolve
#   live each run and never trust a hardcoded index.
#
# Audio:
#   - OFF by default (screen video only).
#   - Opt in with --audio (auto-picks the built-in mic) or --audio-device "Name"/index.
#
# Recording area:
#   - Defaults to the WHOLE chosen screen.
#   - Pass --area w:h:x:y to crop (e.g. --area 1400:900:40:120). The raw capture
#     is always full-screen, so you can re-crop later with --reuse (no re-record).
#
# Output:
#   - Every run writes UNIQUE, timestamped files into OUTDIR (default ./demo-out):
#     <stamp>.raw.mov / <stamp>.mp4 / <stamp>.gif  — never overwrites a prior run.
#   - Add a label with --tag NAME -> <stamp>-NAME.{mp4,gif,raw.mov}.
#
# Usage:
#   ./record-demo.sh --steps demo/steps.sh        # pick screen (if >1), full screen, no audio
#   ./record-demo.sh --steps demo/steps.sh --screen 4 --audio   # force device, +built-in mic
#   ./record-demo.sh --steps demo/steps.sh --area 1400:900:40:120 --tag konnect
#   ./record-demo.sh --list                       # list screens + audio devices, exit
#   ./record-demo.sh --steps demo/steps.sh --no-record   # rehearse the steps, no recording
#   ./record-demo.sh --reuse demo-out/<stamp>.raw.mov    # reprocess a capture (no steps needed)
#
# First real capture triggers a macOS "Screen Recording" permission prompt for
# your terminal app — grant it (System Settings > Privacy & Security), re-run.
#
# Env-var equivalents (flags win): STEPS, DEVICE, SCREEN_NAME, AUDIO, AUDIO_DEVICE,
#   AREA/CROP, TAG, FPS, OUTDIR, SETTLE, PAUSE_BEFORE, PAUSE_AFTER, RECORD,
#   TRIM_START, TRIM_END, MP4_SPEED, GIF_SPEED, GIF_FPS, GIF_WIDTH, MP4_CRF.
set -euo pipefail

DEVICE="${DEVICE:-}"                 # explicit avfoundation screen index (blank = auto/prompt)
SCREEN_NAME="${SCREEN_NAME:-}"       # explicit screen name (blank = auto/prompt)
AUDIO="${AUDIO:-0}"                  # 0 = no audio (default), 1 = record audio
AUDIO_DEVICE="${AUDIO_DEVICE:-}"     # audio device index or name (blank = auto built-in mic)
FPS="${FPS:-30}"
OUTDIR="${OUTDIR:-./demo-out}"
TAG="${TAG:-}"
STEPS="${STEPS:-}"                   # demo steps file (blank = auto-detect ./demo-steps.sh, ./demo/steps.sh)
SETTLE="${SETTLE:-2}"
PAUSE_BEFORE="${PAUSE_BEFORE:-1.2}"
PAUSE_AFTER="${PAUSE_AFTER:-2.5}"
RECORD="${RECORD:-1}"
TRIM_START="${TRIM_START:-}"
TRIM_END="${TRIM_END:-}"
CROP="${CROP:-${AREA:-}}"            # whole screen when blank
MP4_SPEED="${MP4_SPEED:-1.0}"
GIF_SPEED="${GIF_SPEED:-2.0}"
GIF_FPS="${GIF_FPS:-12}"
GIF_WIDTH="${GIF_WIDTH:-1000}"
MP4_CRF="${MP4_CRF:-18}"
REUSE=""; LIST=0

usage() { awk 'NR>=2 && /^set -euo/{exit} NR>=2{sub(/^# ?/,"");print}' "$0"; }

# ── CLI flags (override env) ─────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --screen)       DEVICE="${2:?--screen needs an index}"; shift 2;;
    --screen-name)  SCREEN_NAME="${2:?--screen-name needs a name}"; DEVICE=""; shift 2;;
    --audio)        AUDIO=1; shift;;
    --audio-device) AUDIO=1; AUDIO_DEVICE="${2:?--audio-device needs a name/index}"; shift 2;;
    --no-audio)     AUDIO=0; shift;;
    --area)         CROP="${2:?--area needs w:h:x:y}"; shift 2;;
    --steps)        STEPS="${2:?--steps needs a file}"; shift 2;;
    --tag)          TAG="${2:?--tag needs a label}"; shift 2;;
    --fps)          FPS="${2:?}"; shift 2;;
    --outdir)       OUTDIR="${2:?}"; shift 2;;
    --no-record)    RECORD=0; shift;;
    --reuse)        REUSE="${2:?--reuse needs a file}"; shift 2;;
    --list)         LIST=1; shift;;
    -h|--help)      usage; exit 0;;
    --)             shift; break;;
    -*)             echo "unknown option: $1" >&2; usage; exit 1;;
    *)              REUSE="$1"; shift;;      # bare path = reuse an existing capture
  esac
done

command -v ffmpeg  >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)"; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not found (comes with ffmpeg)"; exit 1; }
command -v jq      >/dev/null || { echo "jq not found (brew install jq)"; exit 1; }

# Auto-detect a steps file when --steps/STEPS wasn't given.
if [ -z "$STEPS" ]; then
  for _c in ./demo-steps.sh ./demo/steps.sh; do
    [ -f "$_c" ] && { STEPS="$_c"; break; }
  done
fi

# ── device discovery ─────────────────────────────────────────────────────────
# `ffmpeg -list_devices` prints to stderr and EXITS NON-ZERO, and grep may miss —
# so every discovery pipeline is guarded (|| true) against set -e/pipefail aborts.
_parse_devices() {   # $1 = 'video' or 'audio'; fills _IDX / _NAME arrays
  _IDX=(); _NAME=()
  local line idx name sect="$1"
  local awkpick
  if [ "$sect" = audio ]; then
    awkpick='/AVFoundation audio devices/{a=1;next} /AVFoundation video devices/{a=0} a'
  else
    awkpick='/AVFoundation video devices/{a=1;next} /AVFoundation audio devices/{a=0} a'
  fi
  while IFS= read -r line; do
    case "$line" in *'] ['*) ;; *) continue;; esac
    idx=$( { printf '%s' "$line" | grep -oE '\] \[[0-9]+\]' | grep -oE '[0-9]+' | head -1; } || true )
    name=${line##*] }               # strip through the last "] " -> device name
    [ -n "$idx" ] && { _IDX+=("$idx"); _NAME+=("$name"); }
  done < <(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | awk "$awkpick" || true)
}
# screens are the video devices whose name starts "Capture screen"
enumerate_screens() {
  _parse_devices video
  SCREENS_IDX=(); SCREENS_NAME=()
  local i
  for i in "${!_IDX[@]}"; do
    case "${_NAME[$i]}" in "Capture screen"*) SCREENS_IDX+=("${_IDX[$i]}"); SCREENS_NAME+=("${_NAME[$i]}");; esac
  done
}
res_hint() {   # best-effort resolution for the Nth screen; never fatal
  system_profiler SPDisplaysDataType 2>/dev/null \
    | grep -E 'Resolution:' | sed -n "$(( $1 + 1 ))p" | sed 's/^ *Resolution: *//' || true
}

choose_screen() {   # sets DEVICE
  [ -n "$DEVICE" ] && return
  enumerate_screens
  if [ -n "$SCREEN_NAME" ]; then
    local i
    for i in "${!SCREENS_NAME[@]}"; do
      [ "${SCREENS_NAME[$i]}" = "$SCREEN_NAME" ] && { DEVICE="${SCREENS_IDX[$i]}"; return; }
    done
    echo "!! screen '$SCREEN_NAME' not found. Run with --list." >&2; exit 1
  fi
  local n=${#SCREENS_IDX[@]}
  [ "$n" -gt 0 ] || { echo "!! no screen-capture devices found. Run with --list." >&2; exit 1; }
  if [ "$n" -eq 1 ]; then
    DEVICE="${SCREENS_IDX[0]}"; echo ">> one screen: ${SCREENS_NAME[0]} -> device $DEVICE"; return
  fi
  if [ ! -r /dev/tty ]; then
    DEVICE="${SCREENS_IDX[0]}"
    echo ">> $n screens but no TTY to prompt -> ${SCREENS_NAME[0]} (device $DEVICE). Use --screen N." >&2; return
  fi
  echo "Multiple screens detected:" >&2
  local i
  for i in "${!SCREENS_IDX[@]}"; do
    printf "  %d) %-18s device %-3s %s\n" "$i" "${SCREENS_NAME[$i]}" "${SCREENS_IDX[$i]}" "$(res_hint "$i")" >&2
  done
  local sel=""
  while :; do
    printf "Choose screen [0-%d]: " "$((n-1))" >&2
    read -r sel < /dev/tty || { echo >&2; exit 1; }
    case "$sel" in ''|*[!0-9]*) echo "  enter a number." >&2; continue;; esac
    [ "$sel" -ge 0 ] && [ "$sel" -lt "$n" ] && break
    echo "  out of range." >&2
  done
  DEVICE="${SCREENS_IDX[$sel]}"
  echo ">> chose ${SCREENS_NAME[$sel]} -> avfoundation device $DEVICE" >&2
}

resolve_audio() {   # sets AUDIO_IDX (+ AUDIO_LABEL)
  _parse_devices audio
  [ "${#_IDX[@]}" -gt 0 ] || { echo "!! no audio input devices found. Run with --list." >&2; exit 1; }
  local i
  if [ -n "$AUDIO_DEVICE" ]; then
    case "$AUDIO_DEVICE" in
      ''|*[!0-9]*)                     # a name
        for i in "${!_NAME[@]}"; do
          [ "${_NAME[$i]}" = "$AUDIO_DEVICE" ] && { AUDIO_IDX="${_IDX[$i]}"; AUDIO_LABEL="${_NAME[$i]}"; return; }
        done
        echo "!! audio device '$AUDIO_DEVICE' not found. Run with --list." >&2; exit 1;;
      *) AUDIO_IDX="$AUDIO_DEVICE"; AUDIO_LABEL="device $AUDIO_DEVICE"; return;;
    esac
  fi
  for i in "${!_NAME[@]}"; do          # auto: prefer the built-in mic
    case "${_NAME[$i]}" in *MacBook*Microphone*) AUDIO_IDX="${_IDX[$i]}"; AUDIO_LABEL="${_NAME[$i]}"; return;; esac
  done
  AUDIO_IDX="${_IDX[0]}"; AUDIO_LABEL="${_NAME[0]}"
}

if [ "$LIST" = "1" ]; then
  enumerate_screens
  echo "Screens:"
  for i in "${!SCREENS_IDX[@]}"; do
    printf "  [%s] %-18s %s\n" "${SCREENS_IDX[$i]}" "${SCREENS_NAME[$i]}" "$(res_hint "$i")"
  done
  _parse_devices audio
  echo "Audio inputs:"
  for i in "${!_IDX[@]}"; do printf "  [%s] %s\n" "${_IDX[$i]}" "${_NAME[$i]}"; done
  exit 0
fi

mkdir -p "$OUTDIR"
STAMP=$(date +%Y%m%d-%H%M%S)
BASE="$STAMP${TAG:+-$TAG}"
MP4="$OUTDIR/$BASE.mp4"; GIF="$OUTDIR/$BASE.gif"; PAL="$OUTDIR/$BASE.palette.png"

bold=$(tput bold 2>/dev/null || true); dim=$(tput dim 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true); reset=$(tput sgr0 2>/dev/null || true)
# Heading colors a steps file can pass as step()'s optional 3rd arg (default green).
c_red=$(tput setaf 1 2>/dev/null || true)
c_green=$(tput setaf 2 2>/dev/null || true)
c_orange=$(tput setaf 208 2>/dev/null || tput setaf 3 2>/dev/null || true)

# Provided to the steps file: print a labeled command, pause, run it, pause.
# Optional 3rd arg = heading color (e.g. $c_red / $c_orange); defaults to green.
step() {
  local title="$1" cmd="$2" color="${3:-$c_green}"
  printf '\n%s━━ %s ━━%s\n' "$bold$color" "$title" "$reset"
  printf '%s$ %s%s\n' "$dim" "$cmd" "$reset"
  sleep "$PAUSE_BEFORE"
  eval "$cmd" || true          # a step failing (e.g. an intentional non-2xx) must not abort
  sleep "$PAUSE_AFTER"
}

# Load the steps file (it sets DEMO_TITLE + defines demo()), then run it paced.
run_demo() {
  if [ -z "$STEPS" ]; then
    echo "!! no demo steps file. Pass --steps FILE (or add ./demo-steps.sh or ./demo/steps.sh)." >&2
    echo "   A steps file sets DEMO_TITLE and defines: demo() { step \"label\" \"command\"; ... }" >&2
    echo "   See demo-steps.example.sh beside this script." >&2
    exit 1
  fi
  [ -r "$STEPS" ] || { echo "!! steps file not readable: $STEPS" >&2; exit 1; }
  DEMO_TITLE=""; unset -f demo 2>/dev/null || true
  # shellcheck disable=SC1090
  source "$STEPS"
  command -v demo >/dev/null 2>&1 || { echo "!! '$STEPS' must define a demo() function (see the example)." >&2; exit 1; }
  clear 2>/dev/null || true
  printf '%s%s%s\n' "$bold" "${DEMO_TITLE:-Demo}" "$reset"
  sleep "$PAUSE_AFTER"
  demo
  printf '\n%s✓ demo complete%s\n' "$bold$cyan" "$reset"
  sleep "$PAUSE_AFTER"
}

# ── CAPTURE + DRIVE ──────────────────────────────────────────────────────────
if [ -n "$REUSE" ]; then
  RAW="$REUSE"
  echo ">> reusing $RAW (skipping capture + steps)"
elif [ "$RECORD" = "0" ]; then
  echo ">> --no-record rehearsal — running steps, no recording"
  run_demo
  exit 0
else
  if [ -z "$STEPS" ] || [ ! -r "$STEPS" ]; then
    echo "!! recording needs a readable steps file. Pass --steps FILE (see demo-steps.example.sh)." >&2
    exit 1
  fi
  RAW="$OUTDIR/$BASE.raw.mov"
  choose_screen
  acodec=(); audin=":none"
  if [ "$AUDIO" = "1" ]; then
    resolve_audio
    audin=":$AUDIO_IDX"; acodec=(-c:a aac -b:a 128k)
    echo ">> audio: ON (${AUDIO_LABEL})"
  else
    echo ">> audio: off (default — enable with --audio)"
  fi
  echo ">> recording ${SCREEN_NAME:-screen} (device $DEVICE @ ${FPS}fps) -> $RAW"
  [ -n "$CROP" ] && echo ">> area: crop $CROP (raw is full-screen; re-crop later with --reuse)" \
                 || echo ">> area: full screen"
  # Clear the screen BEFORE the capture starts, so the recording never opens on
  # leftover terminal output (the status lines above + prior scrollback). The
  # warmup sleep then runs on an already-clean screen.
  clear 2>/dev/null || true
  # -y: unique names mean no clash, but never hang on an overwrite prompt either.
  ffmpeg -hide_banner -y -loglevel error -f avfoundation -framerate "$FPS" -i "${DEVICE}${audin}" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p ${acodec[@]+"${acodec[@]}"} "$RAW" &
  FFPID=$!
  trap 'kill -INT "$FFPID" 2>/dev/null || true' EXIT
  sleep "$SETTLE"     # avfoundation warmup — screen is already clear, nothing stale is captured
  run_demo
  kill -INT "$FFPID" 2>/dev/null || true    # SIGINT => ffmpeg finalizes the moov atom cleanly
  wait "$FFPID" 2>/dev/null || true
  trap - EXIT
  echo ">> recording stopped -> $RAW"
fi

# ── PROCESS: raw -> mp4 + gif ────────────────────────────────────────────────
seek=()
[ -n "$TRIM_START" ] && seek+=(-ss "$TRIM_START")
[ -n "$TRIM_END" ]   && seek+=(-to "$TRIM_END")   # ${seek[@]+...} guards bash 3.2 empty-array + set -u
crop_vf=""; [ -n "$CROP" ] && crop_vf="crop=${CROP},"
pts() { awk -v s="$1" 'BEGIN{ printf "%.6f", 1.0/s }'; }

# Audio for the MP4: only if requested AND the raw actually has an audio track.
mp4_a=(-an)
if [ "$AUDIO" = "1" ]; then
  has_a=$( { ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$RAW" 2>/dev/null | head -1; } || true )
  if [ -n "$has_a" ]; then
    if awk "BEGIN{exit !($MP4_SPEED==1)}"; then
      mp4_a=(-c:a aac -b:a 128k)                       # real-time: keep audio as-is
    else
      mp4_a=(-af "atempo=$MP4_SPEED" -c:a aac -b:a 128k) # atempo valid 0.5–2.0
    fi
  else
    echo ">> note: --audio was set but $RAW has no audio track; MP4 will be silent"
  fi
fi

echo ">> writing $MP4 (speed ${MP4_SPEED}x, crf ${MP4_CRF}, audio: $([ "${mp4_a[0]}" = -an ] && echo off || echo on))"
ffmpeg -hide_banner -y ${seek[@]+"${seek[@]}"} -i "$RAW" \
  -vf "${crop_vf}setpts=$(pts "$MP4_SPEED")*PTS" "${mp4_a[@]}" \
  -c:v libx264 -crf "$MP4_CRF" -preset slow -pix_fmt yuv420p -movflags +faststart "$MP4"

echo ">> writing $GIF (speed ${GIF_SPEED}x, ${GIF_FPS}fps, ${GIF_WIDTH}px)"
gif_vf="${crop_vf}setpts=$(pts "$GIF_SPEED")*PTS,fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos"
ffmpeg -hide_banner -y ${seek[@]+"${seek[@]}"} -i "$RAW" -vf "${gif_vf},palettegen" "$PAL"
ffmpeg -hide_banner -y ${seek[@]+"${seek[@]}"} -i "$RAW" -i "$PAL" -lavfi "${gif_vf} [x]; [x][1:v] paletteuse" "$GIF"
rm -f "$PAL"

echo
echo ">> done:"
echo "   MP4 (edit + narrate): $MP4"
echo "   GIF (inline):         $GIF"
echo
echo ">> REDACT before sharing if any step showed real secrets/PII. Blur a region, e.g.:"
echo "     magick frame.png -fill black -draw \"rectangle 300,220 700,260\" safe.png"
