---
name: demo-media
description: >
  Record, edit, compress, and annotate demo videos and screenshots using ffmpeg
  and ImageMagick. Use when the user wants to turn a screen recording into a GIF
  or shareable MP4, trim/crop/speed-up a video, batch-resize or convert
  screenshots, annotate images (arrows, boxes, callouts), redact/blur sensitive
  regions (PII, tokens, secrets) in demo assets, or build a repeatable
  recording/screenshotting pipeline. Ships a turnkey macOS recorder
  (record-demo.sh) that screen-records, drives a scripted demo, and emits a
  timestamped MP4 + GIF. Triggers on: "screen recording", "record a demo",
  "self-driving demo", "record-demo.sh", "make a GIF", "screenshot workflow",
  "compress video", "trim clip", "crop recording", "annotate screenshot",
  "redact/blur screenshot", "encode/prep a recording for Remotion", "ffmpeg",
  "imagemagick", "magick".
---

# Demo Media: ffmpeg + ImageMagick

Recipes for producing demo videos and screenshots. Tuned for developer
demos: terminal captures, UI walkthroughs, docs assets, Slack/PR shares.

## Turnkey recorder: `record-demo.sh`

This skill ships a macOS recorder — `record-demo.sh`, in this skill's directory.
It screen-records, runs a scripted sequence of demo commands *on camera*, stops,
and writes a timestamped, editable **MP4** (real-time — add a talk track later)
plus a snappy **GIF** (sped up — for inline docs/Slack). One command, walk away.

The recorder is **project-agnostic**: the demo it runs comes from a `--steps`
file you supply, so the same script records any project.

```bash
./record-demo.sh --steps demo/steps.sh                 # pick screen (prompts if >1), full screen, no audio
./record-demo.sh --steps demo/steps.sh --audio --tag v1  # + built-in mic, labeled take
./record-demo.sh --steps demo/steps.sh --area 1400:900:40:120   # crop to a region (w:h:x:y)
./record-demo.sh --steps demo/steps.sh --no-record     # rehearse the steps, no recording
./record-demo.sh --list                                # list screens + audio devices, exit
./record-demo.sh --reuse demo-out/<stamp>.raw.mov      # re-crop / re-speed a capture (no steps needed)
```

### The steps file (`--steps`)

A small shell file that the recorder **sources**, then drives with pacing +
on-screen labels. It sets `DEMO_TITLE` and defines a `demo()` function that calls
`step "<label>" "<command>" [color] [result-label] [note]` once per on-camera command:

```bash
DEMO_TITLE="My Service — quick tour"
HOST="${HOST:-localhost:8080}"

demo() {
  step "1/2  Health check"    "curl -s $HOST/healthz | jq ."
  step "2/2  Create a widget" "curl -s -X POST $HOST/widgets -d '{\"name\":\"demo\"}' | jq ." "$c_red"
  # gate steps that show real secrets: [ \"${INCLUDE_LIVE:-1}\" = 1 ] && step ...
}
```

- `step`, `group`, the pauses, and the heading colors are provided by the recorder — don't redefine them.
- Optional 3rd arg colors the heading: `$c_red`, `$c_green`, `$c_orange` (default green).
- 4th arg labels the output rule (default `Response`; e.g. `Prompt` when the output echoes the sent payload); 5th is a grayed-out note printed before the command.
- Response rules span the content width × `RULE_WIDTH_PCT` (default 175%), capped at the terminal.
- `group "<title>"` prints a section heading to group related steps.
- The command runs under `eval` (pipes/quotes/jq work); a non-zero exit (e.g. an
  intentional error demo) is tolerated, not fatal.
- If `--steps` is omitted, `./demo-steps.sh` then `./demo/steps.sh` are auto-detected.
- Full template: **`demo-steps.example.sh`** beside this script. Keep each project's
  steps file *in that project's repo* (e.g. a tracked `demo/` dir), not here.

Design decisions worth keeping (each fixed a real failure):

- **Screen chosen by name, not index.** avfoundation reorders indices when a
  camera/mic is (un)plugged, so a hardcoded index silently records the wrong
  device (e.g. your webcam). Prompts when more than one screen is present;
  `--screen N` / `--screen-name "Capture screen 1"` to force.
- **Audio OFF by default.** Capture is video-only (`:none`). Opt in with
  `--audio` (auto-picks the built-in mic) or `--audio-device NAME|INDEX`. The MP4
  keeps audio only when the raw actually has a track; the GIF never does.
- **Unique timestamped output** into `demo-out/<stamp>[-tag].{raw.mov,mp4,gif}` —
  never overwrites a prior take. The raw is always full-screen, so `--reuse` lets
  you re-crop / re-speed without re-recording.
- **Warmup lead-in auto-trimmed.** The capture runs for `SETTLE`s before the demo
  banner; terminals that keep prior scrollback/blocks visible record that leftover
  content no `clear` reliably blanks. The outputs trim `SETTLE`s off the start by
  default (the raw keeps everything). `TRIM_START=0` disables; set it to a duration
  to trim a different amount.
- First capture triggers a macOS **Screen Recording** permission prompt for your
  terminal app — grant it (System Settings › Privacy & Security), then re-run.

Everything except the steps file — capture, screen selection, audio, trimming,
the MP4+GIF pipeline — is generic and reusable across projects. `--no-record`
runs the steps without recording so you can rehearse pacing first.

## → Remotion: wrap a recording in branded titles/motion

To turn a raw demo into a polished, titled video (intro card, brand colors,
crossfade into the screen capture), pair this skill with the sibling
**remotion-best-practices** skill — build the composition in React, drop the
recording into the project's `public/`, and render to MP4.

One gotcha bridges the two: a raw retina capture is **5K with sparse keyframes**,
and Remotion Studio seeks frame-by-frame — so it scrubs at a few fps and renders
slowly. Encode a Remotion-friendly copy first: downscale and lay down dense
keyframes.

`record-demo.sh --remotion` does exactly this, emitting `<stamp>.remotion.mp4`
next to the usual outputs (add `--remotion` to `--reuse` to convert an old take).
The equivalent one-off command:

```bash
ffmpeg -i raw.mov -vf "scale=-2:1080:flags=lanczos" \
  -c:v libx264 -crf 20 -preset medium -g 15 -keyint_min 15 -sc_threshold 0 \
  -pix_fmt yuv420p -movflags +faststart demo.mp4
```

- `scale=-2:1080` — downscale to 1080p; `-2` keeps aspect and forces an even
  width (required by yuv420p). Match the height to your composition.
- `-g 15 -keyint_min 15 -sc_threshold 0` — a keyframe every 15 frames (~0.5s at
  30fps), regularly spaced. This is what makes Studio scrubbing smooth. Denser
  keyframes cost file size; ~0.5s is a good balance.
- Then in the composition: `import {Video} from '@remotion/media'` and
  `<Video src={staticFile('demo.mp4')} />`. See the remotion skill for titles,
  transitions, and rendering.

The sections below are the underlying ffmpeg/ImageMagick recipes the script is
built from — reach for them directly for one-off edits or non-recording tasks.

## Tooling notes

- **ImageMagick v7**: the command is `magick`, not `convert`. `convert` is
  removed. `magick mogrify ...` for in-place batch ops.
- **ffmpeg high-quality GIFs need 2 passes** (generate palette, then apply it).
  One-pass GIFs look banded and dirty. Always use the palette method below.
- **MP4 for sharing**: add `-movflags +faststart` so it plays before fully
  downloaded. Use `libx264 -crf` for size/quality (lower CRF = bigger/sharper;
  20–24 is a good demo range).
- Check what's installed: `ffmpeg -version | head -1` and `magick -version | head -1`.
  Install on macOS: `brew install ffmpeg imagemagick`.

## ffmpeg — video

### Record → high-quality GIF (2-pass palette)
```bash
ffmpeg -i in.mov -vf "fps=12,scale=1000:-1:flags=lanczos,palettegen" palette.png
ffmpeg -i in.mov -i palette.png -lavfi "fps=12,scale=1000:-1:flags=lanczos,paletteuse" out.gif
```
Lower `fps` and `scale` width to shrink the GIF. 12 fps / 1000px is a good
balance for terminal demos.

### Trim (lossless, fast — no re-encode)
```bash
ffmpeg -ss 00:00:05 -to 00:00:20 -i in.mov -c copy cut.mov
```
`-ss` before `-i` seeks fast. For frame-exact cuts, drop `-c copy` (re-encodes).

### Crop to a region — `crop=w:h:x:y`
```bash
ffmpeg -i in.mov -vf "crop=1280:720:100:50" cropped.mov
```

### Speed up (cut dead time) — 4×, drop audio
```bash
ffmpeg -i in.mov -vf "setpts=0.25*PTS" -an fast.mov
```
`setpts` factor = 1/speed. Keep audio in sync with `-af "atempo=4.0"` instead of `-an`.

### Compress MP4 for sharing
```bash
ffmpeg -i in.mov -vcodec libx264 -crf 24 -preset slow -movflags +faststart share.mp4
```

### Concatenate clips (same codec)
```bash
printf "file '%s'\n" clip1.mov clip2.mov > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mov
```

### Extract frames / a thumbnail
```bash
ffmpeg -ss 00:00:03 -i in.mov -frames:v 1 thumb.png     # single frame at 3s
ffmpeg -i in.mov -vf fps=1 frame_%03d.png               # 1 frame/sec
```

## ImageMagick — images

### Batch resize + convert (retina → doc-sized)
```bash
magick mogrify -resize 50% -format png *.png
```

### Crop a region — `WxH+X+Y`
```bash
magick shot.png -crop 1200x800+0+100 +repage cropped.png
```
`+repage` resets the virtual canvas after crop — omit it and downstream ops misbehave.

### Annotate a box / arrow (highlight a field)
```bash
magick shot.png -stroke red -strokewidth 3 -fill none \
  -draw "rectangle 400,200 700,260" boxed.png
```

### Redact / blur sensitive region (hide real PII, tokens, secrets)
```bash
magick shot.png -region 400x40+300+220 -blur 0x12 +region redacted.png
```
For hard redaction (unrecoverable), fill solid instead of blurring:
```bash
magick shot.png -fill black -draw "rectangle 300,220 700,260" redacted.png
```

### Clean up terminal grabs — trim + strip metadata + border
```bash
magick shot.png -trim +repage -strip -bordercolor white -border 20 clean.png
```
`-strip` removes EXIF — do this before committing images to a repo.

## Pipeline recipes worth scripting

- **Auto-GIF**: record → trim → speed 2× → 2-pass palette GIF, as one shell
  function that takes a `.mov` and emits a `.gif`. (Realized end-to-end by
  `record-demo.sh` above — read it for a worked example of chaining these.)
- **Screenshot lint**: `magick mogrify` over a dir → resize + `-strip` + `-trim`,
  run before committing assets to `docs/`.
- **Redact pass**: batch-blur (or solid-fill) known PII coordinates across a set
  of screenshots to produce safe, shareable demo assets.

When building a pipeline, verify the region/crop coordinates on one file before
batching — wrong offsets are the most common failure and easy to miss at scale.
