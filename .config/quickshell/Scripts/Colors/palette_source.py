#!/usr/bin/env python3
"""Downscale a wallpaper to a small palette source"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--max-edge", type=int, default=512)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    image = Image.open(args.image)
    if image.format == "GIF":
        image.seek(1)
    # JPEG decodes straight to a reduced size, which is most of the saving on large photos
    if image.format == "JPEG":
        image.draft("RGB", (args.max_edge, args.max_edge))
    image = image.convert("RGB")
    image.thumbnail((args.max_edge, args.max_edge), Image.Resampling.BILINEAR)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(f".{args.output.name}.tmp")
    image.save(temporary, format="PNG")
    temporary.replace(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
