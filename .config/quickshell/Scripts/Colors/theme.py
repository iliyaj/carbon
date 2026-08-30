#!/usr/bin/env python3
"""Wallpaper and Material theme pipeline"""

from __future__ import annotations

import argparse
import configparser
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Sequence


SCHEMES = {
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-fruit-salad",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-rainbow",
    "scheme-tonal-spot",
}
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm"}
VIDEO_OPTIONS = (
    "no-audio loop hwdec=auto scale=bilinear interpolation=no "
    "video-sync=display-resample panscan=1.0 video-scale-x=1.0 "
    "video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"
)

HOME = Path.home()
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state"))
QUICKSHELL_DIR = CONFIG_HOME / "quickshell"
SCRIPT_DIR = Path(__file__).resolve().parent
STATE_DIR = STATE_HOME / "quickshell"
GENERATED_DIR = STATE_DIR / "user/generated"
WALLPAPER_GENERATED_DIR = GENERATED_DIR / "wallpaper"
CURRENT_WALLPAPER = STATE_DIR / "user/current-wallpaper"
MATERIAL_SCSS = GENERATED_DIR / "material_colors.scss"
COLORS_JSON = GENERATED_DIR / "colors.json"
PALETTE_CACHE_DIR = GENERATED_DIR / "palette-source"
PALETTE_MAX_EDGE = 512
PALETTE_CACHE_KEEP = 10
TERMINAL_DIR = GENERATED_DIR / "terminal"
TERM_SCHEME = QUICKSHELL_DIR / "Scripts/Terminal/scheme-base.toml"
MATUGEN_CONFIG = SCRIPT_DIR / "matugen.toml"
HYPRLOCK_CONFIG = GENERATED_DIR / "hyprlock.conf"
HYPRLOCK_TEMPLATE = CONFIG_HOME / "hypr/hyprlock.conf.template"
KDE_GLOBALS = CONFIG_HOME / "kdeglobals"
KDE_SCHEME_DIR = Path("/usr/share/color-schemes")
THUMBNAIL_DIR = Path("/tmp/mpvpaper_thumbnails")


def run(
    command: Sequence[str | Path],
    *,
    check: bool = True,
    capture: bool = False,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(part) for part in command],
        check=check,
        text=True,
        capture_output=capture,
        cwd=cwd,
        env=env,
    )


def detached(command: Sequence[str | Path]) -> None:
    subprocess.Popen(
        [str(part) for part in command],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def notify(title: str, body: str, *extra: str) -> str:
    if not shutil.which("notify-send"):
        return ""
    result = run(["notify-send", "-a", "Wallpaper switcher", *extra, title, body], check=False, capture=True)
    return result.stdout.strip()


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    temporary.write_text(content)
    temporary.replace(path)


def virtualenv_python() -> Path:
    configured = os.environ.get("CARBON_VIRTUAL_ENV", str(STATE_DIR / ".venv"))
    candidate = Path(os.path.expandvars(os.path.expanduser(configured))) / "bin/python"
    if not candidate.exists():
        raise RuntimeError(f"Python environment not found: {candidate}")
    return candidate


def current_mode() -> str:
    result = run(["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"], check=False, capture=True)
    return "dark" if result.stdout.strip().strip("'") == "prefer-dark" else "light"


def set_mode(mode: str) -> None:
    preference = "prefer-dark" if mode == "dark" else "prefer-light"
    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", preference])
    run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", gtk_theme])


def monitor_data() -> list[dict]:
    result = run(["hyprctl", "monitors", "-j"], capture=True)
    return json.loads(result.stdout)


def current_awww_wallpaper() -> str:
    result = run(["awww", "query"], check=False, capture=True)
    for line in result.stdout.splitlines():
        if "image: " in line:
            return line.split("image: ", 1)[1].strip()
    if CURRENT_WALLPAPER.exists():
        return CURRENT_WALLPAPER.read_text().strip()
    return ""


def configured_scheme() -> str:
    config_path = CONFIG_HOME / "carbon/config.json"
    try:
        return json.loads(config_path.read_text()).get("appearance", {}).get("palette", {}).get("type", "auto")
    except (OSError, json.JSONDecodeError):
        return "auto"


def prune_palette_cache() -> None:
    cached = sorted(PALETTE_CACHE_DIR.glob("*.png"), key=lambda entry: entry.stat().st_mtime, reverse=True)
    for stale in cached[PALETTE_CACHE_KEEP:]:
        stale.unlink(missing_ok=True)


# Quantizing a full-resolution wallpaper costs seconds and yields the same palette as a thumbnail
def palette_thumbnail(image: Path) -> Path:
    try:
        stat = image.stat()
    except OSError:
        return image
    key = f"{image}:{stat.st_mtime_ns}:{stat.st_size}:{PALETTE_MAX_EDGE}"
    cached = PALETTE_CACHE_DIR / f"{hashlib.sha256(key.encode()).hexdigest()[:32]}.png"
    if cached.is_file():
        return cached
    result = run([
        virtualenv_python(), SCRIPT_DIR / "palette_source.py",
        "--max-edge", str(PALETTE_MAX_EDGE), "--output", cached, image,
    ], check=False, capture=True)
    if result.returncode != 0 or not cached.is_file():
        print(f"theme.py: could not downscale {image}, using it directly", file=sys.stderr)
        return image
    prune_palette_cache()
    return cached


def detect_scheme(image: Path) -> str:
    result = run([virtualenv_python(), SCRIPT_DIR / "scheme_for_image.py", image], check=False, capture=True)
    detected = result.stdout.strip()
    if result.returncode != 0 or detected not in SCHEMES:
        message = result.stderr.strip() or f"unexpected output '{detected}'"
        print(f"theme.py: automatic scheme detection failed, using scheme-tonal-spot: {message}", file=sys.stderr)
        return "scheme-tonal-spot"
    return detected


def choose_wallpaper() -> str:
    pictures = Path(run(["xdg-user-dir", "PICTURES"], capture=True).stdout.strip())
    start = pictures / "Wallpapers"
    if not start.is_dir():
        start = pictures
    result = run(
        ["kdialog", "--getopenfilename", str(start), "--title", "Choose wallpaper"],
        check=False,
        capture=True,
    )
    return result.stdout.strip()


def cursor_transition_position(focused: dict) -> str:
    result = run(["hyprctl", "cursorpos", "-j"], check=False, capture=True)
    try:
        cursor = json.loads(result.stdout)
        scale = float(focused.get("scale", 1))
        x = int((float(cursor["x"]) - float(focused.get("x", 0))) * scale)
        y = int((float(cursor["y"]) - float(focused.get("y", 0))) * scale)
        return f"{x}, {int(focused['height']) - y}"
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        return "960, 540"


def ensure_video_dependencies() -> bool:
    missing = [program for program in ("mpvpaper", "ffmpeg") if not shutil.which(program)]
    if not missing:
        return True
    notify(
        "Can't switch to video wallpaper",
        "Missing dependencies: " + ", ".join(missing),
        "-c",
        "im.error",
    )
    return False


def set_wallpaper(image: Path, monitors: list[dict]) -> Path:
    run(["pkill", "-9", "-f", "mpvpaper"], check=False)

    if image.suffix.lower() in VIDEO_EXTENSIONS:
        if not ensure_video_dependencies():
            raise RuntimeError("video wallpaper dependencies are unavailable")
        for monitor in monitors:
            detached([
                "mpvpaper", "-o", VIDEO_OPTIONS, monitor["name"], image,
            ])
        THUMBNAIL_DIR.mkdir(parents=True, exist_ok=True)
        thumbnail = THUMBNAIL_DIR / f"{image.name}.jpg"
        run(["ffmpeg", "-y", "-i", image, "-vframes", "1", thumbnail])
        if not thumbnail.is_file():
            raise RuntimeError("could not extract a video frame for color generation")
        return thumbnail

    focused = next((monitor for monitor in monitors if monitor.get("focused")), monitors[0])
    detached([
        "awww", "img", image,
        "--transition-step", "100",
        "--transition-fps", "120",
        "--transition-type", "grow",
        "--transition-angle", "30",
        "--transition-duration", "1",
        "--transition-pos", cursor_transition_position(focused),
    ])
    atomic_write(CURRENT_WALLPAPER, str(image) + "\n")
    return image


def generate_material(source_kind: str, source: str, mode: str, scheme: str) -> None:
    command = [
        "matugen", "--config", MATUGEN_CONFIG, "--mode", mode, "--type", scheme,
    ]
    if source_kind == "image":
        command.extend(["--source-color-index", "0"])
        command.extend(["image", source])
    else:
        command.extend(["color", "hex", source.removeprefix("#")])
    run(command)


def generate_scss(source_kind: str, source: str, mode: str, scheme: str) -> None:
    command: list[str | Path] = [
        virtualenv_python(), SCRIPT_DIR / "generate_colors_material.py",
        "--mode", mode,
        "--scheme", scheme,
        "--termscheme", TERM_SCHEME,
        "--blend_bg_fg",
        "--cache", STATE_DIR / "user/color.txt",
    ]
    command.extend(["--path", source] if source_kind == "image" else ["--color", source])
    result = run(command, capture=True)
    atomic_write(MATERIAL_SCSS, result.stdout)


def scss_colors() -> dict[str, str]:
    colors: dict[str, str] = {}
    pattern = re.compile(r"^\$(\w+):\s*(#[0-9A-Fa-f]{6});$")
    for line in MATERIAL_SCSS.read_text().splitlines():
        match = pattern.match(line.strip())
        if match:
            colors[match.group(1)] = match.group(2)
    return colors


def apply_terminal(colors: dict[str, str]) -> None:
    TERMINAL_DIR.mkdir(parents=True, exist_ok=True)
    terms = [colors[f"term{index}"] for index in range(16)]
    kitty_lines = [
        "# Auto-generated by quickshell - DO NOT EDIT MANUALLY",
        "# Edit colors in quickshell settings instead", "",
        f"foreground {terms[7]}", f"background {terms[0]}",
        f"selection_foreground {terms[0]}", f"selection_background {terms[7]}", "",
    ]
    ghostty_lines = [
        "# Auto-generated by quickshell - DO NOT EDIT MANUALLY",
        "# Edit colors in quickshell settings instead", "",
        f"foreground = {terms[7]}", f"background = {terms[0]}",
        f"selection-foreground = {terms[0]}", f"selection-background = {terms[7]}", "",
    ]
    labels = ("Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White")
    for index, label in enumerate(labels):
        kitty_lines.extend([f"# {label}", f"color{index} {terms[index]}", f"color{index + 8} {terms[index + 8]}", ""])
        ghostty_lines.extend([f"# {label}", f"palette = {index}={terms[index]}", f"palette = {index + 8}={terms[index + 8]}", ""])
    atomic_write(TERMINAL_DIR / "kitty-colors.conf", "\n".join(kitty_lines))
    atomic_write(TERMINAL_DIR / "ghostty-colors.conf", "\n".join(ghostty_lines))


def kconfig() -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    return parser


def apply_kde(mode: str) -> None:
    scheme_name = "BreezeDark" if mode == "dark" else "BreezeLight"
    scheme_path = KDE_SCHEME_DIR / f"{scheme_name}.colors"
    if not scheme_path.is_file():
        raise RuntimeError(f"KDE Breeze color scheme not found: {scheme_path}")

    scheme = kconfig()
    settings = kconfig()
    try:
        scheme.read(scheme_path)
        if KDE_GLOBALS.is_file():
            settings.read(KDE_GLOBALS)
    except configparser.Error as error:
        raise RuntimeError(f"could not read KDE color settings: {error}") from error

    for section in scheme.sections():
        if not settings.has_section(section):
            settings.add_section(section)
        if section == "General":
            settings[section]["ColorScheme"] = scheme[section]["ColorScheme"]
            settings.remove_option(section, "ColorSchemeHash")
            continue
        for key, value in scheme.items(section):
            settings[section][key] = value

    settings["KDE"]["widgetStyle"] = "Breeze"
    output = io.StringIO()
    settings.write(output, space_around_delimiters=False)
    atomic_write(KDE_GLOBALS, output.getvalue())

    if shutil.which("dbus-send"):
        run([
            "dbus-send", "--session", "--type=signal", "/KGlobalSettings",
            "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0",
        ], check=False)


def update_hyprlock(palette_source: str) -> None:
    if not COLORS_JSON.is_file():
        return
    if HYPRLOCK_CONFIG.is_file():
        content = HYPRLOCK_CONFIG.read_text()
    elif HYPRLOCK_TEMPLATE.is_file():
        content = HYPRLOCK_TEMPLATE.read_text()
    else:
        return
    colors = json.loads(COLORS_JSON.read_text())
    replacements = {
        "$text_color": f"rgba({colors['primary_fixed'].removeprefix('#')}FF)",
        "$entry_background_color": f"rgba({colors['on_primary_fixed'].removeprefix('#')}11)",
        "$entry_border_color": f"rgba({colors['outline'].removeprefix('#')}55)",
        "$entry_color": f"rgba({colors['primary_fixed'].removeprefix('#')}FF)",
    }
    for variable, value in replacements.items():
        content = re.sub(rf"^{re.escape(variable)}\s*=.*$", f"{variable} = {value}", content, flags=re.MULTILINE)
    if palette_source:
        content = re.sub(r"^(\s*path\s*=).*$", rf"\1 {palette_source}", content, count=1, flags=re.MULTILINE)
    atomic_write(HYPRLOCK_CONFIG, content)


def generate_least_busy_region(source: str, monitors: list[dict]) -> None:
    script = CONFIG_HOME / "matugen/scripts/least_busy_region.py"
    source_path = Path(source)
    if not script.is_file() or not source_path.is_file():
        return
    width = min(int(monitor["width"]) for monitor in monitors)
    height = min(int(monitor["height"]) for monitor in monitors)
    result = run([
        virtualenv_python(), script,
        "--screen-width", str(width),
        "--screen-height", str(height),
        "--width", "300", "--height", "200",
        source_path,
    ], check=False, capture=True)
    if result.returncode == 0:
        atomic_write(WALLPAPER_GENERATED_DIR / "least_busy_region.json", result.stdout)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wallpaper", nargs="?")
    parser.add_argument("--image")
    parser.add_argument("--mode", choices=("dark", "light"))
    parser.add_argument("--type", dest="scheme")
    parser.add_argument("--color", nargs="?", const="")
    parser.add_argument("--noswitch", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    mode = args.mode or current_mode()
    scheme = args.scheme or configured_scheme()
    image_text = args.image or args.wallpaper or ""

    if args.noswitch and not image_text:
        image_text = current_awww_wallpaper()
    if args.color is None and not args.noswitch and not image_text:
        image_text = choose_wallpaper()
    if args.color is None and not image_text:
        print("No wallpaper selected", file=sys.stderr)
        return 0

    if scheme == "auto":
        scheme = detect_scheme(palette_thumbnail(Path(image_text))) if image_text and Path(image_text).is_file() else "scheme-tonal-spot"
    if scheme not in SCHEMES:
        print(f"Invalid scheme '{scheme}', using scheme-tonal-spot", file=sys.stderr)
        scheme = "scheme-tonal-spot"

    monitors = monitor_data()
    palette_source = image_text
    if args.color is not None:
        color = args.color or run(["hyprpicker", "--no-fancy"], check=False, capture=True).stdout.strip()
        if not re.fullmatch(r"#?[0-9A-Fa-f]{6}", color):
            raise RuntimeError("a six-digit hex color is required")
        source_kind, source = "color", "#" + color.removeprefix("#")
    else:
        image = Path(image_text).expanduser().resolve()
        if not image.is_file():
            raise RuntimeError(f"wallpaper does not exist: {image}")
        if not args.noswitch:
            palette_source = str(set_wallpaper(image, monitors))
        else:
            palette_source = str(image)
        source_kind, source = "image", str(palette_thumbnail(Path(palette_source)))

    set_mode(mode)
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    generate_material(source_kind, source, mode, scheme)
    generate_scss(source_kind, source, mode, scheme)
    colors = scss_colors()
    apply_terminal(colors)
    apply_kde(mode)
    update_hyprlock(palette_source)
    if palette_source:
        generate_least_busy_region(palette_source, monitors)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        notify("Wallpaper update failed", str(error), "-c", "im.error")
        print(f"theme.py: {error}", file=sys.stderr)
        raise SystemExit(1)
