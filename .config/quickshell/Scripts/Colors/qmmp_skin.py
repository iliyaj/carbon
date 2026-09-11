#!/usr/bin/env python3
"""Recolor an indexed-bitmap Qmmp skin from a Matugen palette."""

from __future__ import annotations

import argparse
import colorsys
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import time
import zipfile


Color = tuple[int, int, int]


def parse_color(value: str) -> Color:
    value = value.removeprefix("#")
    if len(value) != 6:
        raise ValueError(f"expected #RRGGBB color, got {value!r}")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def format_color(color: Color) -> str:
    return "#" + "".join(f"{channel:02X}" for channel in color)


def mix(first: Color, second: Color, amount: float) -> Color:
    amount = max(0.0, min(1.0, amount))
    return tuple(round(a + (b - a) * amount) for a, b in zip(first, second))


def sample(stops: list[tuple[float, Color]], position: float) -> Color:
    position = max(0.0, min(1.0, position))
    for index in range(1, len(stops)):
        left_position, left_color = stops[index - 1]
        right_position, right_color = stops[index]
        if position <= right_position:
            span = right_position - left_position
            amount = 0.0 if span == 0 else (position - left_position) / span
            return mix(left_color, right_color, amount)
    return stops[-1][1]


def required_colors(palette: dict[str, str]) -> dict[str, Color]:
    names = {
        "background",
        "on_primary",
        "on_surface",
        "on_surface_variant",
        "outline",
        "outline_variant",
        "primary",
        "primary_container",
        "primary_fixed",
        "primary_fixed_dim",
        "surface_container",
        "surface_container_high",
        "surface_container_highest",
        "surface_container_low",
        "surface_container_lowest",
        "tertiary",
        "tertiary_container",
        "tertiary_fixed",
    }
    missing = sorted(names - palette.keys())
    if missing:
        raise ValueError(f"Matugen palette is missing: {', '.join(missing)}")
    return {name: parse_color(palette[name]) for name in names}


def recolor(color: Color, colors: dict[str, Color]) -> Color:
    red, green, blue = (channel / 255 for channel in color)
    hue, saturation, value = colorsys.rgb_to_hsv(red, green, blue)
    luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

    neutral = sample([
        (0.00, colors["surface_container_lowest"]),
        (0.08, colors["background"]),
        (0.22, colors["surface_container_low"]),
        (0.36, colors["surface_container"]),
        (0.48, colors["outline_variant"]),
        (0.62, colors["outline"]),
        (0.82, colors["on_surface_variant"]),
        (1.00, colors["on_surface"]),
    ], luminance)

    # Warm source pixels get the tertiary family; all other chroma becomes primary.
    family = "tertiary" if hue < 0.20 or hue > 0.94 else "primary"
    accent = sample([
        (0.00, colors["surface_container_lowest"]),
        (0.18, colors["on_primary"]),
        (0.42, colors[f"{family}_container"]),
        (0.72, colors[family]),
        (0.90, colors[f"{family}_fixed"]),
        (1.00, colors["on_surface"]),
    ], value)
    accent_strength = max(0.0, min(1.0, (saturation - 0.08) / 0.42))
    return mix(neutral, accent, accent_strength)


def recolor_bmp(data: bytes, colors: dict[str, Color]) -> bytes:
    if len(data) < 54 or data[:2] != b"BM":
        return data

    dib_size = struct.unpack_from("<I", data, 14)[0]
    if dib_size < 40 or len(data) < 14 + dib_size:
        return data

    bit_depth = struct.unpack_from("<H", data, 28)[0]
    if bit_depth > 8:
        return data

    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    palette_offset = 14 + dib_size
    available_entries = max(0, (pixel_offset - palette_offset) // 4)
    colors_used = struct.unpack_from("<I", data, 46)[0]
    entry_count = min(colors_used or 1 << bit_depth, available_entries)

    result = bytearray(data)
    for index in range(entry_count):
        offset = palette_offset + index * 4
        blue, green, red, reserved = result[offset:offset + 4]
        mapped_red, mapped_green, mapped_blue = recolor((red, green, blue), colors)
        result[offset:offset + 4] = bytes((mapped_blue, mapped_green, mapped_red, reserved))
    return bytes(result)


def playlist_colors(colors: dict[str, Color]) -> bytes:
    lines = [
        "[Text]",
        f"Normal={format_color(colors['primary'])}",
        f"Current={format_color(colors['on_surface'])}",
        f"NormalBG={format_color(colors['surface_container_lowest'])}",
        f"SelectedBG={format_color(colors['primary_container'])}",
        "Font=Arial",
        "",
    ]
    return "\r\n".join(lines).encode("ascii")


def visualizer_colors(colors: dict[str, Color]) -> bytes:
    spectrum = [
        mix(colors["primary_fixed"], colors["primary_container"], index / 15)
        for index in range(16)
    ]
    entries = [
        colors["surface_container_lowest"],
        colors["surface_container_high"],
        *spectrum,
        colors["on_surface"],
        colors["on_surface_variant"],
        colors["outline"],
        colors["outline_variant"],
        colors["primary_container"],
        colors["primary"],
    ]
    return "".join(f"{red},{green},{blue},\r\n" for red, green, blue in entries).encode("ascii")


def generate(source: Path, output: Path, palette_path: Path) -> tuple[int, int, bool]:
    palette = json.loads(palette_path.read_text())
    colors = required_colors(palette)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp.{os.getpid()}")
    changed_bitmaps = 0
    copied_entries = 0

    try:
        with zipfile.ZipFile(source, "r") as source_archive:
            with zipfile.ZipFile(temporary, "w") as output_archive:
                for info in source_archive.infolist():
                    data = source_archive.read(info.filename)
                    name = info.filename.casefold()
                    if name.endswith(".bmp"):
                        recolored = recolor_bmp(data, colors)
                        changed_bitmaps += recolored != data
                        data = recolored
                    elif name == "pledit.txt":
                        data = playlist_colors(colors)
                    elif name == "viscolor.txt":
                        data = visualizer_colors(colors)
                    else:
                        copied_entries += 1
                    output_archive.writestr(info, data)
        archive_changed = not output.is_file() or output.read_bytes() != temporary.read_bytes()
        if archive_changed:
            temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)

    return changed_bitmaps, copied_entries, archive_changed


def qmmp_command(qmmp: str, *arguments: str, capture: bool = False) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            [qmmp, "--no-start", *arguments],
            check=False,
            capture_output=capture,
            text=True,
            timeout=3,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"Qmmp did not respond to {' '.join(arguments)}") from error


def qmmp_running() -> bool:
    return subprocess.run(
        ["pgrep", "-x", "qmmp"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def playback_status(qmmp: str) -> str | None:
    result = qmmp_command(qmmp, "--status", capture=True)
    first_line = result.stdout.splitlines()[0] if result.stdout else ""
    if result.returncode != 0:
        return None
    for status in ("playing", "paused", "stopped"):
        if first_line.startswith(f"[{status}]"):
            return status
    return None


def clear_skin_cache(output: Path) -> None:
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    skin_cache = cache_home / "qmmp/skinned/skin"
    if skin_cache.is_symlink() or skin_cache.is_file():
        skin_cache.unlink()
    elif skin_cache.is_dir():
        shutil.rmtree(skin_cache)

    thumbnail_dir = cache_home / "qmmp/skinned/thumbs"
    if thumbnail_dir.is_dir():
        expected_name = f"{output.name}.bmp".casefold()
        for thumbnail in thumbnail_dir.iterdir():
            if thumbnail.name.casefold() == expected_name:
                thumbnail.unlink()


def start_qmmp(qmmp: str) -> None:
    command = [qmmp, "--ui", "skinned", "-platform", "xcb"]
    systemd_run = shutil.which("systemd-run")
    if systemd_run:
        unit = f"carbon-qmmp-skin-{os.getpid()}-{time.monotonic_ns()}"
        result = subprocess.run(
            [systemd_run, "--user", "--quiet", "--collect", "--unit", unit, *command],
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return
    setsid = shutil.which("setsid")
    if setsid:
        subprocess.run(
            [setsid, "-f", *command],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return
    subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def wait_for_qmmp(qmmp: str, expected: str | None = None) -> str | None:
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        status = playback_status(qmmp) if qmmp_running() else None
        if status is not None and (expected is None or status == expected):
            return status
        time.sleep(0.1)
    return None


def reload_qmmp(output: Path) -> str:
    qmmp = shutil.which("qmmp")
    was_running = bool(qmmp and qmmp_running())

    if was_running and qmmp:
        qmmp_command(qmmp, "--stop")
        if wait_for_qmmp(qmmp, "stopped") is None:
            raise RuntimeError("Qmmp did not stop playback before the skin reload")
        time.sleep(0.1)
        qmmp_command(qmmp, "--quit")
        deadline = time.monotonic() + 5
        while qmmp_running() and time.monotonic() < deadline:
            time.sleep(0.1)
        if qmmp_running():
            raise RuntimeError("Qmmp did not exit for the skin reload")

    clear_skin_cache(output)
    if not was_running or not qmmp:
        return "cache cleared; Qmmp will use the skin on its next start"

    start_qmmp(qmmp)
    if wait_for_qmmp(qmmp) is None:
        raise RuntimeError("Qmmp did not start after the skin reload")
    qmmp_command(qmmp, "--stop")
    if wait_for_qmmp(qmmp, "stopped") is None:
        raise RuntimeError("Qmmp did not remain stopped after the skin reload")
    return "Qmmp restarted with playback stopped"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="source .wsz archive")
    parser.add_argument("--output", required=True, type=Path, help="generated .wsz archive")
    parser.add_argument("--palette", required=True, type=Path, help="Matugen colors.json")
    parser.add_argument("--reload-qmmp", action="store_true", help="reload a running Qmmp instance")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    changed_bitmaps, copied_entries, archive_changed = generate(args.source, args.output, args.palette)
    action = "Generated" if archive_changed else "Unchanged"
    print(f"{action} {args.output} ({changed_bitmaps} bitmaps recolored, {copied_entries} entries copied)")
    if args.reload_qmmp and archive_changed:
        print(reload_qmmp(args.output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
