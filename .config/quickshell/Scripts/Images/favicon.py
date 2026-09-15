#!/usr/bin/env python3
"""Fetch a favicon atomically and print its cached file URL on success."""

import argparse
import hashlib
from http.client import HTTPException
from pathlib import Path
import signal
import sys
import tempfile
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ENDPOINT = "https://www.google.com/s2/favicons"
MAX_BYTES = 1024 * 1024


def fetch(domain: str, cache_dir: Path, user_agent: str) -> Path:
    if not domain:
        raise ValueError("empty favicon domain")
    cache_dir = cache_dir.absolute()
    key = hashlib.sha256(domain.encode("utf-8")).hexdigest()
    cached = cache_dir / f"{key}.ico"
    if cached.is_file() and cached.stat().st_size > 0:
        return cached

    request = Request(
        f"{ENDPOINT}?{urlencode({'domain': domain, 'sz': 32})}",
        headers={"User-Agent": user_agent},
    )
    with urlopen(request, timeout=15) as response:
        if response.status != 200 or not response.headers.get_content_type().startswith("image/"):
            raise ValueError("favicon response is not an image")
        data = response.read(MAX_BYTES + 1)
        length = response.headers.get("Content-Length")
        if not data or len(data) > MAX_BYTES or (length is not None and len(data) != int(length)):
            raise ValueError("empty, oversized, or incomplete favicon response")

    # Only complete downloads enter the cache; concurrent delegates use separate staging files.
    cache_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=cache_dir, prefix=f".{key}.", suffix=".tmp", delete=False) as output:
        staging = Path(output.name)
        try:
            output.write(data)
            output.flush()
            staging.replace(cached)
        finally:
            staging.unlink(missing_ok=True)
    return cached


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("domain")
    parser.add_argument("cache_dir", type=Path)
    parser.add_argument("user_agent")
    args = parser.parse_args()
    # Let Quickshell's termination request unwind any staging-file cleanup.
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(128 + signum))
    try:
        cached = fetch(args.domain, args.cache_dir, args.user_agent)
    except (OSError, ValueError, HTTPException) as error:
        print(f"Favicon download failed: {error}", file=sys.stderr)
        return 1
    print(cached.as_uri())
    return 0


if __name__ == "__main__":
    sys.exit(main())
