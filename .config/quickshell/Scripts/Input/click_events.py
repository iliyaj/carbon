#!/usr/bin/env python3
"""Stream global pointer button presses as JSON lines for Carbon."""

from __future__ import annotations

import argparse
import ctypes
import glob
import json
import os
import selectors
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path


EVENT_STRUCT = struct.Struct("@llHHi")
EV_KEY = 0x01
BUTTON_NAMES = {
    0x110: "left",
    0x111: "right",
    0x112: "middle",
}
RESCAN_INTERVAL_SECONDS = 2.0
PR_SET_PDEATHSIG = 1


def exit_when_parent_dies() -> None:
    """Ask Linux to terminate the listener if its Quickshell parent disappears."""
    parent_pid = os.getppid()
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM, 0, 0, 0) != 0:
        error_number = ctypes.get_errno()
        print(
            f"click-events: cannot set parent-death signal: {os.strerror(error_number)}",
            file=sys.stderr,
        )
        return

    # The parent may have exited between getppid() and prctl().
    if os.getppid() != parent_pid:
        raise SystemExit(0)


def pointer_event_paths() -> list[str]:
    """Return event nodes whose kernel handlers identify them as pointers."""
    devices_file = Path("/proc/bus/input/devices")
    try:
        blocks = devices_file.read_text(encoding="utf-8").split("\n\n")
    except OSError as error:
        print(f"click-events: cannot inspect input devices: {error}", file=sys.stderr)
        return []

    paths: set[str] = set()
    for block in blocks:
        handlers = next(
            (line.removeprefix("H: Handlers=") for line in block.splitlines()
             if line.startswith("H: Handlers=")),
            "",
        ).split()
        if not any(handler.startswith("mouse") for handler in handlers):
            continue
        event_handler = next(
            (handler for handler in handlers if handler.startswith("event")),
            None,
        )
        if event_handler is not None:
            paths.add(f"/dev/input/{event_handler}")

    # Fall back to every event node if procfs is unavailable or incomplete. Nodes
    # without pointer button codes remain silent and are harmless to monitor.
    if not paths:
        paths.update(glob.glob("/dev/input/event*"))
    return sorted(paths)


def cursor_position() -> tuple[float, float] | None:
    try:
        result = subprocess.run(
            ["hyprctl", "cursorpos", "-j"],
            check=True,
            capture_output=True,
            text=True,
            timeout=0.25,
        )
        position = json.loads(result.stdout)
        return float(position["x"]), float(position["y"])
    except (FileNotFoundError, KeyError, ValueError, json.JSONDecodeError,
            subprocess.SubprocessError) as error:
        print(f"click-events: cannot read cursor position: {error}", file=sys.stderr)
        return None


def emit_click(button: str) -> None:
    position = cursor_position()
    if position is None:
        return
    print(
        json.dumps({"button": button, "x": position[0], "y": position[1]},
                   separators=(",", ":")),
        flush=True,
    )


class PointerDevices:
    def __init__(self) -> None:
        self.selector = selectors.DefaultSelector()
        self.files: dict[str, object] = {}
        self.buffers: dict[int, bytes] = {}
        self.reported_failures: set[str] = set()

    def close(self) -> None:
        for path in list(self.files):
            self.remove(path)
        self.selector.close()

    def remove(self, path: str) -> None:
        device = self.files.pop(path, None)
        if device is None:
            return
        try:
            self.selector.unregister(device)
        except (KeyError, ValueError):
            pass
        self.buffers.pop(device.fileno(), None)
        device.close()

    def rescan(self) -> None:
        available = set(pointer_event_paths())
        for path in set(self.files) - available:
            self.remove(path)

        for path in sorted(available - set(self.files)):
            try:
                device = open(path, "rb", buffering=0)
                os.set_blocking(device.fileno(), False)
                self.selector.register(device, selectors.EVENT_READ, path)
                self.files[path] = device
                self.buffers[device.fileno()] = b""
                self.reported_failures.discard(path)
            except OSError as error:
                if path not in self.reported_failures:
                    print(f"click-events: cannot read {path}: {error}", file=sys.stderr)
                    self.reported_failures.add(path)

    def read_ready(self, device: object, path: str) -> None:
        try:
            chunk = os.read(device.fileno(), EVENT_STRUCT.size * 32)
        except BlockingIOError:
            return
        except OSError as error:
            print(f"click-events: lost {path}: {error}", file=sys.stderr)
            self.remove(path)
            return

        if not chunk:
            self.remove(path)
            return

        buffer = self.buffers.get(device.fileno(), b"") + chunk
        complete_bytes = len(buffer) - (len(buffer) % EVENT_STRUCT.size)
        self.buffers[device.fileno()] = buffer[complete_bytes:]
        for offset in range(0, complete_bytes, EVENT_STRUCT.size):
            _, _, event_type, code, value = EVENT_STRUCT.unpack_from(buffer, offset)
            button = BUTTON_NAMES.get(code)
            if event_type == EV_KEY and button is not None and value == 1:
                emit_click(button)

    def run(self) -> None:
        next_rescan = 0.0
        while True:
            now = time.monotonic()
            if now >= next_rescan:
                self.rescan()
                next_rescan = now + RESCAN_INTERVAL_SECONDS

            timeout = max(0.0, next_rescan - time.monotonic())
            for key, _ in self.selector.select(timeout):
                self.read_ready(key.fileobj, key.data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--list-devices",
        action="store_true",
        help="print the pointer event nodes Carbon would monitor and exit",
    )
    args = parser.parse_args()

    if args.list_devices:
        print("\n".join(pointer_event_paths()))
        return 0

    exit_when_parent_dies()
    devices = PointerDevices()
    try:
        devices.run()
    except KeyboardInterrupt:
        return 0
    finally:
        devices.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
