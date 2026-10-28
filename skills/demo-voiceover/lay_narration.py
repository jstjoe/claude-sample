"""Lay narration clips over a finished cut at given start times and level the mix.

    python3 lay_narration.py cut.mp4 narrated.mp4 1.5:intro.mp3 6.4:diagram.mp3 ...

Each argument after the two paths is <start seconds>:<clip>. The picture is
copied untouched. Every clip gets a 20 ms fade-in so one that starts mid-sound
cannot click. The mix is normalised to -16 LUFS with a -1.5 dBTP ceiling,
which is the usual target for web video.
"""

from __future__ import annotations

import subprocess
import sys


def duration(path: str) -> float:
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                                capture_output=True, text=True, check=True).stdout)


def main(video: str, out: str, *placements: str) -> None:
    total = duration(video)
    inputs, chains = [], []
    for i, placement in enumerate(placements):
        start, clip = placement.split(":", 1)
        inputs += ["-i", clip]
        ms = int(float(start) * 1000)
        chains.append(f"[{i + 1}:a]aresample=48000,aformat=channel_layouts=stereo,afade=t=in:d=0.02,"
                      f"adelay={ms}|{ms}[a{i}]")
    mix = "".join(f"[a{i}]" for i in range(len(placements)))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, *inputs, "-filter_complex",
                    ";".join(chains) + f";{mix}amix=inputs={len(placements)}:normalize=0,"
                    f"loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,apad=whole_dur={total:.3f}[a]",
                    "-map", "0:v", "-map", "[a]", "-t", f"{total:.3f}", "-c:v", "copy",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out], check=True)
    print(f"{out} {duration(out):.1f}s with {len(placements)} clips")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
