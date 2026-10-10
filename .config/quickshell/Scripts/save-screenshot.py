#!/usr/bin/env python3
"""Publish a complete screenshot without overwriting files, then copy its file path."""

import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--background", type=Path, help="Composite the source annotation layer over this image")
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    temporary = None
    try:
        args.destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            dir=args.destination.parent, prefix=".screenshot-", suffix=".png", delete=False
        ) as target:
            temporary = Path(target.name)
            if args.background is None:
                with args.source.open("rb") as source:
                    shutil.copyfileobj(source, target)
        if args.background is not None:
            # Canvas buffers include display scaling; fit the layer to the original pixels.
            subprocess.run(["magick", str(args.background), str(args.source),
                "-geometry", "%[fx:u[0].w]x%[fx:u[0].h]!",
                "-compose", "over", "-composite", str(temporary)], check=True)
        # A hard link publishes the finished file atomically and refuses an existing name.
        os.link(temporary, args.destination)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Could not save the screenshot: {error}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    try:
        subprocess.run(["wl-copy", "--type", "text/plain", "--", str(args.destination.resolve())],
            check=True, start_new_session=True)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Image saved, but file path copy failed: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
