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
#   - --remotion also emits <stamp>.remotion.mp4: downscaled + dense-keyframe
#     encode that scrubs smoothly in Remotion Studio. Drop it into a Remotion
#     project's public/ to wrap the demo in branded titles/motion (pairs with the
#     remotion-best-practices skill). Works with --reuse too (no re-record).
#
# Usage:
#   ./record-demo.sh --steps demo/steps.sh        # pick screen (if >1), full screen, no audio
#   ./record-demo.sh --steps demo/steps.sh --screen 4 --audio   # force device, +built-in mic
#   ./record-demo.sh --steps demo/steps.sh --area 1400:900:40:120 --tag konnect
#   ./record-demo.sh --list                       # list screens + audio devices, exit
#   ./record-demo.sh --steps demo/steps.sh --no-record   # rehearse the steps, no recording
#   ./record-demo.sh --steps demo/steps.sh --remotion    # + a Remotion-ready encode for public/
#   ./record-demo.sh --reuse demo-out/<stamp>.raw.mov    # reprocess a capture (no steps needed)
#   ./record-demo.sh --reuse demo-out/<stamp>.raw.mov --remotion   # add a Remotion encode to an old take
#
# First real capture triggers a macOS "Screen Recording" permission prompt for
# your terminal app — grant it (System Settings > Privacy & Security), re-run.
#
# Env-var equivalents (flags win): STEPS, DEVICE, SCREEN_NAME, AUDIO, AUDIO_DEVICE,
#   AREA/CROP, TAG, FPS, OUTDIR, SETTLE, PAUSE_BEFORE, PAUSE_AFTER, RECORD,
#   TRIM_START, TRIM_END, MP4_SPEED, GIF_SPEED, GIF_FPS, GIF_WIDTH, MP4_CRF,
#   REMOTION, REMOTION_HEIGHT, REMOTION_GOP.
set -euo pipefail

DEVICE="${DEVICE:-}"                 # explicit avfoundation screen index (blank = auto/prompt)
SCREEN_NAME="${SCREEN_NAME:-}"       # explicit screen name (blank = auto/prompt)
AUDIO="${AUDIO:-0}"                  # 0 = no audio (default), 1 = record audio
AUDIO_DEVICE="${AUDIO_DEVICE:-}"     # audio device index or name (blank = auto built-in mic)
FPS="${FPS:-30}"
OUTDIR="${OUTDIR:-./demo-out}"
TAG="${TAG:-}"
STEPS="${STEPS:-}"                   # demo steps file (blank = auto-detect ./demo-steps.sh, ./demo/steps.sh)
SETTLE="${SETTLE:-2}"               # warmup before the demo starts; also the default lead-in trimmed
PAUSE_BEFORE="${PAUSE_BEFORE:-1.2}"
PAUSE_AFTER="${PAUSE_AFTER:-2.5}"
HL_SENSITIVE="${HL_SENSITIVE:-}"                       # regex of PII to highlight red in payload/output (steps file sets it)
HL_TOKENS="${HL_TOKENS:-\[[A-Za-z0-9_]+\]}"           # regex of tokens to highlight green (default: [BRACKETED] tokens)
RECORD="${RECORD:-1}"
TRIM_START="${TRIM_START:-}"        # trim off the START; blank => auto-trim the SETTLE lead-in, 0 => keep all
TRIM_END="${TRIM_END:-}"
CROP="${CROP:-${AREA:-}}"            # whole screen when blank
MP4_SPEED="${MP4_SPEED:-1.0}"
GIF_SPEED="${GIF_SPEED:-2.0}"
GIF_FPS="${GIF_FPS:-12}"
GIF_WIDTH="${GIF_WIDTH:-1000}"
MP4_CRF="${MP4_CRF:-18}"
REMOTION="${REMOTION:-0}"           # 1 = also emit a Remotion-ready encode (see --remotion)
REMOTION_HEIGHT="${REMOTION_HEIGHT:-1080}"  # target height for the Remotion encode (width auto, aspect kept)
REMOTION_GOP="${REMOTION_GOP:-}"    # keyframe interval for the Remotion encode (blank => fps/2 ≈ every 0.5s)
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
    --remotion)     REMOTION=1; shift;;
    --remotion-height) REMOTION=1; REMOTION_HEIGHT="${2:?--remotion-height needs a number}"; shift 2;;
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
RMP4="$OUTDIR/$BASE.remotion.mp4"   # Remotion-ready encode (only written with --remotion)

bold=$(tput bold 2>/dev/null || true); dim=$(tput dim 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true); reset=$(tput sgr0 2>/dev/null || true)
# Heading colors a steps file can pass as step()'s optional 3rd arg (default green).
c_red=$(tput setaf 1 2>/dev/null || true)
c_green=$(tput setaf 2 2>/dev/null || true)
c_orange=$(tput setaf 208 2>/dev/null || tput setaf 3 2>/dev/null || true)
c_purple=$(tput setaf 99 2>/dev/null || tput setaf 5 2>/dev/null || true)   # Skyflow-ish purple (title/headings)
c_json=$(tput setaf 7 2>/dev/null || true)         # request payload / JSON (white)
rev=$(tput rev 2>/dev/null || true)                # reverse video (closing banner)
# Dusty highlight tones — the ONLY red/green in the demo, reserved for data.
hl_red=$(tput setaf 174 2>/dev/null || tput setaf 1 2>/dev/null || true)    # dusty rose (PII)
hl_green=$(tput setaf 108 2>/dev/null || tput setaf 2 2>/dev/null || true)  # sage (tokens)

# Emit N box-drawing horizontals (nothing when N<=0). Used to size response rules.
rule() { local n="${1:-0}"; [ "$n" -gt 0 ] && printf '─%.0s' $(seq 1 "$n") || true; }

# Highlight matches in $1: HL_SENSITIVE (PII) in dusty red, HL_TOKENS (Skyflow
# tokens) in sage green. $2 = base color to resume after each match (so surrounding
# text keeps its color). Steps files set HL_SENSITIVE; HL_TOKENS defaults to bracket tokens.
hl() {
  local s="$1" base="${2:-}"
  [ -n "$HL_SENSITIVE" ] && s=$(printf '%s' "$s" | sed -E "s/(${HL_SENSITIVE})/${bold}${hl_red}\\1${reset}${base}/g")
  [ -n "$HL_TOKENS" ]    && s=$(printf '%s' "$s" | sed -E "s/(${HL_TOKENS})/${bold}${hl_green}\\1${reset}${base}/g")
  printf '%s' "$s"
}

# Provided to the steps file: render one example — a heading, an optional dim
# note, the command (with any -d JSON payload broken onto its own highlighted
# line), then the result under a labeled, colored rule.
#   step "<title>" "<command>" [color] [result-label] [note]
#   color        heading/rule color (default green)
#   result-label label over the output rule (default "Response"; e.g. "Prompt"
#                for echo routes where the output IS the sent payload)
#   note         a grayed-out one-liner shown before the command
step() {
  local title="$1" cmd="$2" color="${3:-$c_green}" label="${4:-Response}" note="${5:-}"

  # Prominent per-example heading + optional dim note describing the call.
  printf '\n\n%s▎ %s%s\n' "$bold$color" "$title" "$reset"
  [ -n "$note" ] && printf '%s# %s%s\n' "$dim" "$note" "$reset"
  printf '\n'

  # Command, dim — but pull the -d '<payload>' onto its own bright line so the
  # JSON stands out (a break before and after). JSON has no single quotes, so the
  # closing ' is unambiguous. Non-curl commands print as-is.
  if [[ $cmd == *"-d '"* ]]; then
    local before="${cmd%%-d \'*}" rest="${cmd#*-d \'}"
    local payload="${rest%%\'*}" after="${rest#*\'}"
    printf '%s$ %s-d \047%s\n\n'   "$dim" "$before" "$reset"
    printf '      %s%s%s\n\n'      "$bold$c_json" "$(hl "$payload" "$bold$c_json")" "$reset"
    printf '%s   \047%s%s\n'       "$dim" "$after" "$reset"
  else
    printf '%s$ %s%s\n' "$dim" "$cmd" "$reset"
  fi
  sleep "$PAUSE_BEFORE"

  # Run, capture, and show the result under a colored label (no border rules).
  local out; out="$(eval "$cmd" 2>&1)" || true
  [ -n "$out" ] || out="(no output)"
  printf '\n%s%s%s\n' "$bold$color" "$label" "$reset"          # colored label
  printf '%s%s%s\n' "$color" "$(rule "${#label}")" "$reset"    # underline, label width
  printf '%s\n' "$(hl "$out")"
  sleep "$PAUSE_AFTER"
}

# Provided to the steps file: a section heading to group related steps.
group() {
  printf '\n\n%s═══ %s ═══%s\n' "$bold$cyan" "$1" "$reset"
  sleep "$PAUSE_BEFORE"
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
  local _t="${DEMO_TITLE:-Demo}"
  printf '%s%s%s\n' "$bold$c_purple" "$_t" "$reset"
  printf '%s%s%s\n' "$c_purple" "$(rule "${#_t}")" "$reset"   # purple underline, title width
  sleep "$PAUSE_AFTER"
  demo
  printf '\n\n%s%s  ✓  AI APIs secured!  %s\n\n' "$bold$c_green" "$rev" "$reset"
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
  # Send ffmpeg's own output to a log, NOT the terminal. Its startup chatter (the
  # objc warning + avfoundation pixel-format negotiation) would otherwise print
  # onto the screen we're capturing and show up in the opening frames. </dev/null
  # so a backgrounded ffmpeg never blocks on tty stdin.
  # -y: unique names mean no clash, but never hang on an overwrite prompt either.
  FFLOG="$OUTDIR/$BASE.ffmpeg.log"
  ffmpeg -hide_banner -y -loglevel error -f avfoundation -framerate "$FPS" -i "${DEVICE}${audin}" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p ${acodec[@]+"${acodec[@]}"} "$RAW" \
    </dev/null >"$FFLOG" 2>&1 &
  FFPID=$!
  trap 'kill -INT "$FFPID" 2>/dev/null || true' EXIT
  sleep "$SETTLE"     # avfoundation warmup; this lead-in is trimmed off the outputs in post
  run_demo
  kill -INT "$FFPID" 2>/dev/null || true    # SIGINT => ffmpeg finalizes the moov atom cleanly
  wait "$FFPID" 2>/dev/null || true
  trap - EXIT
  # ffmpeg's chatter is hidden now, so surface real failures (empty capture).
  [ -s "$RAW" ] || { echo "!! recording produced no data — see $FFLOG:" >&2; tail -5 "$FFLOG" >&2; exit 1; }
  echo ">> recording stopped -> $RAW"
fi

# ── PROCESS: raw -> mp4 + gif ────────────────────────────────────────────────
# Auto-trim the warmup lead-in. The capture runs for SETTLE seconds before the
# demo banner (avfoundation warmup); terminals that keep prior scrollback/blocks
# visible mean that window records leftover terminal content no `clear` reliably
# blanks. Trimming SETTLE off the start drops it deterministically, whatever the
# terminal does. Override with TRIM_START (e.g. 00:00:03); TRIM_START=0 keeps all.
lead="${TRIM_START:-$SETTLE}"
seek=()
{ [ -n "$lead" ] && [ "$lead" != "0" ]; } && seek+=(-ss "$lead")
[ -n "$TRIM_END" ] && seek+=(-to "$TRIM_END")     # ${seek[@]+...} guards bash 3.2 empty-array + set -u
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

# ── OPTIONAL: raw -> Remotion-ready encode ───────────────────────────────────
# A raw retina capture is huge (often 5K) with sparse keyframes, so Remotion
# Studio — which seeks frame-by-frame — scrubs at a few fps and renders slowly.
# This encode fixes both: downscale to REMOTION_HEIGHT and lay down dense
# keyframes (every ~0.5s) so every frame is cheap to seek. Real-time (no speed
# change) so the clip's frames line up 1:1 with the composition timeline. Drop
# the file into your Remotion project's public/ and reference with staticFile().
if [ "$REMOTION" = "1" ]; then
  gop="${REMOTION_GOP:-$(( FPS / 2 ))}"; [ "$gop" -ge 1 ] || gop=1
  # Audio only if the raw has a track (kept real-time; Remotion controls timing).
  rmp4_a=(-an)
  if [ "$AUDIO" = "1" ]; then
    has_ra=$( { ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$RAW" 2>/dev/null | head -1; } || true )
    [ -n "$has_ra" ] && rmp4_a=(-c:a aac -b:a 128k)
  fi
  echo ">> writing $RMP4 (Remotion-ready: ${REMOTION_HEIGHT}p, keyframe every ${gop}f, faststart)"
  # scale=-2 keeps aspect and forces an even width (required by yuv420p/libx264).
  ffmpeg -hide_banner -y ${seek[@]+"${seek[@]}"} -i "$RAW" \
    -vf "${crop_vf}scale=-2:${REMOTION_HEIGHT}:flags=lanczos" "${rmp4_a[@]}" \
    -c:v libx264 -crf 20 -preset medium -g "$gop" -keyint_min "$gop" -sc_threshold 0 \
    -pix_fmt yuv420p -movflags +faststart "$RMP4"
fi

echo
echo ">> done:"
echo "   MP4 (edit + narrate): $MP4"
echo "   GIF (inline):         $GIF"
[ "$REMOTION" = "1" ] && echo "   Remotion (public/):   $RMP4"
echo
echo ">> REDACT before sharing if any step showed real secrets/PII. Blur a region, e.g.:"
echo "     magick frame.png -fill black -draw \"rectangle 300,220 700,260\" safe.png"
