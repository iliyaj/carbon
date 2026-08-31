#!/usr/bin/env python3
# prints the mic's loudness as a 0..1 value, one line per window

import array
import math
import os
import subprocess
import sys

RATE = 8000
WINDOW = 400  # 50 ms
FLOOR_DB = -50.0


def main() -> int:
    source = sys.argv[1] if len(sys.argv) > 1 else "@DEFAULT_SOURCE@"
    command = [
        "parec",
        "--device", source,
        "--format=s16le",
        f"--rate={RATE}",
        "--channels=1",
        "--latency-msec=50",
        "--client-name=carbon-mic-level",
    ]
    try:
        capture = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as error:
        print(f"mic_level: cannot start parec: {error}", file=sys.stderr)
        return 1

    chunk_bytes = WINDOW * 2
    try:
        while True:
            chunk = capture.stdout.read(chunk_bytes)
            if len(chunk) < chunk_bytes:
                break
            samples = array.array("h")
            samples.frombytes(chunk)
            energy = sum(sample * sample for sample in samples) / len(samples)
            rms = math.sqrt(energy) / 32768.0
            db = 20.0 * math.log10(rms) if rms > 1e-7 else FLOOR_DB
            level = (max(db, FLOOR_DB) - FLOOR_DB) / -FLOOR_DB
            print(f"{level:.3f}", flush=True)
    except (BrokenPipeError, KeyboardInterrupt):
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
    finally:
        capture.terminate()
        capture.wait()
    return 0


if __name__ == "__main__":
    sys.exit(main())
