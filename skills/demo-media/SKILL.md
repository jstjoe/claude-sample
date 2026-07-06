---
name: demo-media
description: >
  Record, edit, compress, and annotate demo videos and screenshots using ffmpeg
  and ImageMagick. Use when the user wants to turn a screen recording into a GIF
  or shareable MP4, trim/crop/speed-up a video, batch-resize or convert
  screenshots, annotate images (arrows, boxes, callouts), redact/blur sensitive
  regions (PII, tokens, secrets) in demo assets, or build a repeatable
  recording/screenshotting pipeline. Triggers on: "screen recording", "make a
  GIF", "record a demo", "screenshot workflow", "compress video", "trim clip",
  "crop recording", "annotate screenshot", "redact/blur screenshot", "ffmpeg",
  "imagemagick", "magick".
---

# Demo Media: ffmpeg + ImageMagick

Recipes for producing demo videos and screenshots. Tuned for developer
demos: terminal captures, UI walkthroughs, docs assets, Slack/PR shares.

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
  function that takes a `.mov` and emits a `.gif`.
- **Screenshot lint**: `magick mogrify` over a dir → resize + `-strip` + `-trim`,
  run before committing assets to `docs/`.
- **Redact pass**: batch-blur (or solid-fill) known PII coordinates across a set
  of screenshots to produce safe, shareable demo assets.

When building a pipeline, verify the region/crop coordinates on one file before
batching — wrong offsets are the most common failure and easy to miss at scale.
