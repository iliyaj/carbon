#!/usr/bin/env python3
"""Find the quietest region of a wallpaper for the desktop widgets"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from materialyoucolor.quantize import QuantizeCelebi
import numpy as np
from PIL import Image


# Match how the compositor presents the wallpaper, so regions map onto screen coordinates
def fit_to_screen(image: Image.Image, screen: tuple[int, int], mode: str) -> Image.Image:
    width, height = image.size
    scale_width, scale_height = screen[0] / width, screen[1] / height
    scale = max(scale_width, scale_height) if mode == "fill" else min(scale_width, scale_height)
    scaled = image.resize((max(1, round(width * scale)), max(1, round(height * scale))), Image.Resampling.LANCZOS)
    left = max(0, (scaled.width - screen[0]) // 2)
    top = max(0, (scaled.height - screen[1]) // 2)
    return scaled.crop((left, top, min(scaled.width, left + screen[0]), min(scaled.height, top + screen[1])))


# Summed-area tables give every window's mean and variance in two array operations
def window_variance(luma: np.ndarray, region: tuple[int, int]) -> np.ndarray:
    region_width, region_height = region
    values = luma.astype(np.float64)
    integral = np.pad(values.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    integral_squared = np.pad((values ** 2).cumsum(0).cumsum(1), ((1, 0), (1, 0)))

    def windows(table: np.ndarray) -> np.ndarray:
        return (table[region_height:, region_width:] - table[:-region_height, region_width:]
                - table[region_height:, :-region_width] + table[:-region_height, :-region_width])

    area = region_width * region_height
    mean = windows(integral) / area
    return windows(integral_squared) / area - mean ** 2


def quietest_corner(variance: np.ndarray, padding: int) -> tuple[int, int, float]:
    inset = variance[padding:variance.shape[0] - padding, padding:variance.shape[1] - padding]
    offset = padding
    if inset.size == 0:
        inset, offset = variance, 0
    flat = int(np.argmin(inset))
    y, x = divmod(flat, inset.shape[1])
    return x + offset, y + offset, float(inset[y, x])


def dominant_color(image: Image.Image, box: tuple[int, int, int, int]) -> str:
    region = np.asarray(image.crop(box).convert("RGB")).reshape(-1, 3)
    if region.size == 0:
        return "#000000"
    lit = region[np.any(region > 10, axis=1)]
    pixels = lit if lit.shape[0] else region
    counts = QuantizeCelebi([tuple(int(channel) for channel in pixel) for pixel in pixels], 16)
    argb = max(counts.items(), key=lambda entry: entry[1])[0]
    return "#{:06x}".format(argb & 0xFFFFFF)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--width", type=int, default=300)
    parser.add_argument("--height", type=int, default=200)
    parser.add_argument("--screen-width", type=int, default=1920)
    parser.add_argument("--screen-height", type=int, default=1080)
    parser.add_argument("--screen-mode", choices=("fill", "fit"), default="fill")
    parser.add_argument("--padding", type=int, default=50)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        source = Image.open(args.image)
    except (OSError, ValueError) as error:
        print(f"least_busy_region.py: could not read {args.image}: {error}", file=sys.stderr)
        return 1
    fitted = fit_to_screen(source, (args.screen_width, args.screen_height), args.screen_mode)
    region = (min(args.width, fitted.width), min(args.height, fitted.height))
    variance = window_variance(np.asarray(fitted.convert("L")), region)
    x, y, quietest = quietest_corner(variance, max(0, args.padding))
    print(json.dumps({
        "center_x": x + region[0] // 2,
        "center_y": y + region[1] // 2,
        "width": region[0],
        "height": region[1],
        "variance": quietest,
        "dominant_color": dominant_color(fitted, (x, y, x + region[0], y + region[1])),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
