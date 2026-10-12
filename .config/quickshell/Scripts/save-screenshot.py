#!/usr/bin/env python3
"""Encode one flattened screenshot and save, copy, or launch it without a shell."""

import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile

# Raster encoders only: document/vector delegates are not screenshot formats.
FORMATS = {
    "png": ("PNG", "image/png", ("png",)),
    "jpeg": ("JPEG", "image/jpeg", ("jpg", "jpeg", "jfif")),
    "webp": ("WebP", "image/webp", ("webp",)),
    "bmp": ("BMP", "image/bmp", ("bmp",)),
    "tiff": ("TIFF", "image/tiff", ("tif", "tiff")),
    "avif": ("AVIF", "image/avif", ("avif",)),
    "ppm": ("PPM", "image/x-portable-pixmap", ("ppm",)),
    "pgm": ("PGM", "image/x-portable-graymap", ("pgm",)),
    "pbm": ("PBM", "image/x-portable-bitmap", ("pbm",)),
    "xbm": ("XBM", "image/x-xbitmap", ("xbm",)),
    "xpm": ("XPM", "image/x-xpixmap", ("xpm",)),
}


def run_process(command, *, stdin=None, text=False, start_new_session=False):
    # Launched applications may inherit stdio; pipes would hold the editor until they close.
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(command, stdin=stdin, stdout=output, stderr=errors,
                                   start_new_session=start_new_session)
        try:
            process.wait()
        except BaseException:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise
        output.seek(0)
        errors.seek(0)
        stdout, stderr = output.read(), errors.read()
        if text:
            stdout, stderr = stdout.decode(), stderr.decode(errors="replace")
        if process.returncode:
            raise subprocess.CalledProcessError(process.returncode, command, stdout, stderr)
        return stdout


def supported_formats():
    listing = run_process(["magick", "-list", "format"], text=True)
    writable = {m.group(1).lower() for line in listing.splitlines()
                if (m := re.match(r"\s*(\w+)\*?\s+\w+\s+[r-]w[+-]\s", line))}
    return [{"id": key, "label": label, "mime": mime, "extensions": list(extensions)}
            for key, (label, mime, extensions) in FORMATS.items() if key in writable]


def desktop_file(application):
    # Respect XDG precedence and nested desktop IDs; gio owns Exec/field-code parsing.
    roots = [Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))]
    roots += [Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    identifier = application if application.endswith(".desktop") else application + ".desktop"
    for base in roots:
        directory = base / "applications"
        direct = directory / identifier
        if direct.is_file():
            return direct
        for candidate in directory.rglob("*.desktop"):
            if "-".join(candidate.relative_to(directory).parts) == identifier:
                return candidate
    raise ValueError("The selected application's desktop entry is no longer available.")


def encode(args, target, image_format):
    command = ["magick", "-"]
    command += ["-strip"]
    if args.rotation:
        command += ["-rotate", str(args.rotation)]
    if image_format in ("jpeg", "bmp", "ppm", "pgm", "pbm", "xbm", "xpm"):
        command += ["-background", "white", "-alpha", "remove", "-alpha", "off"]
    command += ["-quality", str(args.quality), image_format + ":" + str(target)]
    with args.source.open("rb") as source:
        run_process(command, stdin=source)


def publish_new(source, destination):
    # RENAME_NOREPLACE is atomic without requiring hard-link support (e.g. FAT).
    rename = ctypes.CDLL(None, use_errno=True).renameat2
    rename.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
    rename.restype = ctypes.c_int
    if rename(-100, os.fsencode(source), -100, os.fsencode(destination), 1) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(destination))


def pins_directory():
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "carbon/screenshots/pins"


def clipboard(path, mime):
    with path.open("rb") as image:
        run_process(["wl-copy", "--type", mime], stdin=image, start_new_session=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path)
    parser.add_argument("destination", nargs="?", type=Path)
    parser.add_argument("--action", choices=("save", "copy", "save-copy", "copy-path", "open", "pin"), default="save-copy")
    parser.add_argument("--format", default="png")
    parser.add_argument("--quality", type=int, default=90)
    parser.add_argument("--clipboard-format", choices=("png", "jpeg"), default="png")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--original", type=Path)
    parser.add_argument("--application", default="")
    parser.add_argument("--rotation", type=int, choices=(0, 90, 180, 270), default=0)
    parser.add_argument("--formats", action="store_true")
    parser.add_argument("--copy-path-after-save", action="store_true")
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    temporary = None
    saved = ""
    clipboard_temporary = None
    keep = False
    try:
        if args.formats:
            print(json.dumps(supported_formats()))
            return 0
        if args.action == "copy-path":
            if not args.destination or not args.destination.is_file():
                raise ValueError("Save the image before copying its file path.")
            run_process(["wl-copy", "--type", "text/plain", "--", str(args.destination.resolve())],
                        start_new_session=True)
            print(json.dumps({"action": args.action, "path": str(args.destination), "copied": True}))
            return 0
        if not args.source or not args.source.is_file():
            raise ValueError("The rendered screenshot is unavailable. Please try again.")
        image_format = args.clipboard_format if args.action == "copy" else "png" if args.action == "pin" else args.format.lower()
        if image_format == "jpg":
            image_format = "jpeg"
        if image_format not in {f["id"] for f in supported_formats()}:
            raise ValueError("Unsupported screenshot format: " + args.format)
        if not 1 <= args.quality <= 100:
            raise ValueError("Image quality must be between 1 and 100.")
        if args.action in ("save", "save-copy"):
            if not args.destination:
                raise ValueError("Choose a destination for the screenshot.")
            destination = args.destination.absolute()
            if destination.suffix.lower().lstrip(".") not in FORMATS[image_format][2]:
                raise ValueError("The filename extension does not match the selected image format.")
            if destination.resolve() in {p.resolve() for p in (args.source, args.original) if p}:
                raise ValueError("Choose a new filename; the original image must be preserved.")
            if destination.exists() and not args.overwrite:
                raise ValueError("The destination already exists. Use Save as to confirm replacement.")
            destination.parent.mkdir(parents=True, exist_ok=True)
            directory = destination.parent
        elif args.action == "pin":
            # Pins own unrotated full-resolution copies in a fixed cache directory only.
            directory = pins_directory()
            if not args.destination or args.destination.parent != directory or not re.fullmatch(r"pin-[\w.-]+\.png", args.destination.name):
                raise ValueError("Pin images must use a generated name in " + str(directory) + ".")
            if args.rotation:
                raise ValueError("Pins keep the unrotated image; rotate when copying or saving.")
            directory.mkdir(parents=True, exist_ok=True)
            destination = args.destination
        else:
            directory = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "carbon/screenshots"
            directory.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=directory, prefix="Screenshot-" if args.action == "open" else ".screenshot-", suffix="." + FORMATS[image_format][2][0], delete=False) as target:
            temporary = Path(target.name)
        encode(args, temporary, image_format)
        if args.action == "pin":
            publish_new(temporary, destination)
            saved = str(destination)
        if args.action in ("save", "save-copy"):
            if args.overwrite:
                os.replace(temporary, destination)
            else:
                publish_new(temporary, destination)
            saved = str(destination)
        if args.action in ("copy", "save-copy"):
            try:
                clipboard_path = temporary if temporary.exists() else destination
                if image_format != args.clipboard_format:
                    with tempfile.NamedTemporaryFile(dir=directory, prefix=".screenshot-", suffix="." + args.clipboard_format, delete=False) as target:
                        clipboard_temporary = Path(target.name)
                    encode(args, clipboard_temporary, args.clipboard_format)
                    clipboard_path = clipboard_temporary
                clipboard(clipboard_path, FORMATS[args.clipboard_format][1])
            except (OSError, subprocess.CalledProcessError) as error:
                if not saved:
                    raise
                print(json.dumps({"action": args.action, "path": saved, "copied": False}))
                print("Image saved to " + saved + ", but image copy failed: " + str(error), file=sys.stderr)
                return 2
        if saved and args.copy_path_after_save and args.action in ("save", "save-copy"):
            run_process(["wl-copy", "--type", "text/plain", "--", saved], start_new_session=True)
        if args.action == "open":
            command = ["gio", "launch", str(desktop_file(args.application)), str(temporary)] if args.application else ["gio", "open", str(temporary)]
            # Launch may hand off the file before gio returns; cancellation must preserve it.
            keep = True
            try:
                run_process(command, start_new_session=True)
            except (OSError, subprocess.CalledProcessError):
                keep = False
                raise
            saved = str(temporary)
        print(json.dumps({"action": args.action, "path": saved, "copied": args.action in ("copy", "save-copy")}))
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = error.stderr.decode(errors="replace").strip() if isinstance(error, subprocess.CalledProcessError) and isinstance(error.stderr, bytes) else str(error)
        print("Screenshot " + args.action + " failed: " + detail, file=sys.stderr)
        return 1
    finally:
        if clipboard_temporary is not None:
            clipboard_temporary.unlink(missing_ok=True)
        if temporary is not None and not keep:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
