"""Snap OCR highlight boxes to the rows of ink they actually cover.

Vision's boxes are close horizontally but drift a few pixels vertically, so a
box can ride above its text. This finds the run of dark rows under each box,
stopping at table rules and blank gaps, and centres the box on it.

    uv run --with pillow python fit_boxes.py <frame.png> <boxes.json>

Prints the fitted boxes as JSON.
"""

from __future__ import annotations

import json
import sys

from PIL import Image

DARK = 140   # luma below this counts as ink
RULE = 0.8   # a row this dark across the box is a table rule, not text
INK = 0.02   # a row needs this much ink to count as part of the text
GAP = 2      # blank rows allowed inside one line of text
REACH = 30   # how far above and below the OCR centre to look


def fit(img: Image.Image, box: dict) -> dict:
    x0, x1 = int(box["x"]), int(box["x"] + box["w"])
    cy = int(box["y"] + box["h"] / 2)
    px = img.load()

    def ink(y: int) -> float:
        return sum(px[x, y] < DARK for x in range(x0, x1)) / max(1, x1 - x0)

    rows = {y: ink(y) for y in range(cy - REACH, cy + REACH + 1)}
    text = {y for y, f in rows.items() if INK < f < RULE}
    if not text:
        return box
    # Start from the inked row nearest the OCR centre and grow both ways.
    seed = min(text, key=lambda y: abs(y - cy))
    top = bottom = seed
    for step, edge in ((-1, "top"), (1, "bottom")):
        y, blank = seed, 0
        while blank <= GAP:
            y += step
            if y not in rows or rows[y] >= RULE:
                break
            if y in text:
                blank = 0
                top, bottom = (y, bottom) if edge == "top" else (top, y)
            else:
                blank += 1
    return {**box, "y": top, "h": bottom - top + 1}


def main(frame: str, boxes_json: str) -> None:
    img = Image.open(frame).convert("L")
    boxes = json.load(open(boxes_json))
    json.dump([fit(img, b) for b in boxes], sys.stdout, indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:])
