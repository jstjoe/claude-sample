"""Generate a narration as one continuous ElevenLabs take and split it per scene.

One request per scene makes every clip start cold, and the joins sound choppy.
This reads every segment in a single request with character timestamps, then
cuts the take inside the real pauses between segments so the delivery flows
across scene boundaries.

    python3 voiceover_take.py narration.json demo-out/audio/v4 [model]

narration.json holds a voice id, a model id, optional voice settings and the
segments. See narration.example.json beside this script. ELEVENLABS_API_KEY
must be set. ELEVENLABS_VOICE_ID overrides the file's voice and
ELEVENLABS_OUTPUT_FORMAT overrides the default mp3_44100_128.

Writes take.mp3, alignment.json and one <segment id>.mp3 per segment into the
output directory and prints where each segment sits in the take.
"""

from __future__ import annotations

import array
import base64
import json
import math
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.elevenlabs.io/v1/text-to-speech/{voice}/with-timestamps?output_format={fmt}"
# mp3_44100_192 and higher need the Creator tier or above.
FORMAT = os.environ.get("ELEVENLABS_OUTPUT_FORMAT", "mp3_44100_128")
SETTINGS = {"stability": 0.5, "similarity_boost": 0.8, "style": 0.15, "use_speaker_boost": True, "speed": 1.05}
BREAK = "\n\n"  # a paragraph break between segments reads as a natural pause
BEFORE, AFTER = 0.12, 0.3  # seconds kept around each segment for breaths and decay
QUIET = -60  # dBFS below which a 10 ms frame counts as silence


def request(voice: str, text: str, model: str, settings: dict) -> dict:
    body = {"text": text, "model_id": model, "voice_settings": settings}
    req = urllib.request.Request(API.format(voice=voice, fmt=FORMAT), data=json.dumps(body).encode(), method="POST",
                                 headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"],
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        sys.exit(f"ElevenLabs refused the request: {err.code} {err.read().decode()[:400]}")


def loudness(take: Path) -> list[float]:
    """The take's level in dBFS for every 10 ms."""
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", str(take), "-ac", "1", "-ar", "16000", "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    a, w = array.array("h", pcm), 160
    return [20 * math.log10(max(1.0, (sum(x * x for x in a[i:i + w]) / w) ** 0.5) / 32768)
            for i in range(0, len(a) - w, w)]


def pause(db: list[float], end: float, start: float) -> tuple[float, float]:
    """The longest silent run near a boundary as (first, last) seconds.

    The alignment's end times run about 0.4 seconds late, so the search
    reaches well before the previous segment's reported end. Falls back to the
    reported times when it finds no silence.
    """
    lo, hi = max(0, int((end - 0.8) * 100)), min(len(db), int((start + 0.3) * 100))
    best, run_start = (0, 0), None
    for i in range(lo, hi + 1):
        quiet = i < hi and db[i] < QUIET
        if quiet and run_start is None:
            run_start = i
        elif not quiet and run_start is not None:
            if i - run_start > best[1] - best[0]:
                best = (run_start, i)
            run_start = None
    return (best[0] / 100, best[1] / 100) if best[1] > best[0] else (end, start)


def main(script: str, out_dir: str, model: str | None = None) -> None:
    config = json.loads(Path(script).read_text())
    segments = config["segments"]
    voice = os.environ.get("ELEVENLABS_VOICE_ID") or config["voice_id"]
    model = model or config.get("model_id", "eleven_v4")
    text = BREAK.join(s["text"] for s in segments)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    result = request(voice, text, model, {**SETTINGS, **config.get("voice_settings", {})})
    take = out / "take.mp3"
    take.write_bytes(base64.b64decode(result["audio_base64"]))
    align = result["alignment"]
    (out / "alignment.json").write_text(json.dumps(align))
    chars, starts, ends = align["characters"], align["character_start_times_seconds"], align["character_end_times_seconds"]
    if "".join(chars) != text:
        sys.exit("The alignment does not match the text, so the segment boundaries cannot be found.")

    # Where each segment's first and last spoken character fall in the take.
    spans, offset = [], 0
    for s in segments:
        first, last = offset, offset + len(s["text"]) - 1
        spans.append((starts[first], ends[last]))
        offset = last + 1 + len(BREAK)

    total = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                  str(take)], capture_output=True, text=True, check=True).stdout)
    db = loudness(take)
    gaps = [pause(db, spans[i][1], spans[i + 1][0]) for i in range(len(spans) - 1)]
    for i, s in enumerate(segments):
        # Start just before the speech that follows a pause and end shortly
        # after the speech that precedes one, never past the pause's middle.
        a = max(sum(gaps[i - 1]) / 2, gaps[i - 1][1] - BEFORE) if i else 0.0
        b = min(sum(gaps[i]) / 2, gaps[i][0] + AFTER) if i + 1 < len(segments) else total
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.3f}", "-to", f"{b:.3f}", "-i", str(take),
                        "-af", f"afade=t=in:d=0.02,afade=t=out:st={b - a - 0.08:.3f}:d=0.08",
                        "-c:a", "libmp3lame", "-b:a", "192k", str(out / f"{s['id']}.mp3")], check=True)
        print(f"{s['id']:<12} {a:6.2f} to {b:6.2f}  {b - a:5.2f}s")
    print(f"{take} {total:.2f}s with {model}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(*sys.argv[1:4])
