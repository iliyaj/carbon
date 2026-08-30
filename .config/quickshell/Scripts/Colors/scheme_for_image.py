#!/usr/bin/env python3
"""Pick a material scheme from how colorful an image is"""

from __future__ import annotations

import sys

import numpy as np
from PIL import Image


# Hasler and Suesstrunk's colorfulness metric
def image_colorfulness(pixels: np.ndarray) -> float:
    red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    rg = np.absolute(red - green)
    yb = np.absolute(0.5 * (red + green) - blue)
    deviation = np.sqrt(np.std(rg) ** 2 + np.std(yb) ** 2)
    mean = np.sqrt(np.mean(rg) ** 2 + np.mean(yb) ** 2)
    return float(deviation + 0.3 * mean)


# scheme-content respects the image's colors very well, but it might
# look too saturated, so we only use it for not very colorful images to be safe
def pick_scheme(colorfulness: float) -> str:
    if colorfulness < 20:
        return "scheme-content"
    if colorfulness < 50:
        return "scheme-neutral"
    return "scheme-tonal-spot"


def load_pixels(path: str) -> np.ndarray:
    image = Image.open(path)
    if image.format == "GIF":
        image.seek(1)
    return np.asarray(image.convert("RGB"), dtype=float)


def main() -> int:
    args = sys.argv[1:]
    colorfulness_mode = "--colorfulness" in args
    if colorfulness_mode:
        args.remove("--colorfulness")
    if not args:
        print("scheme-tonal-spot")
        print("scheme_for_image.py: an image path is required", file=sys.stderr)
        return 1
    try:
        pixels = load_pixels(args[0])
    except (OSError, ValueError) as error:
        print("scheme-tonal-spot")
        print(f"scheme_for_image.py: could not read {args[0]}: {error}", file=sys.stderr)
        return 1
    colorfulness = image_colorfulness(pixels)
    print(colorfulness if colorfulness_mode else pick_scheme(colorfulness))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
