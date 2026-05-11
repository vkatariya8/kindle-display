#!/usr/bin/env python3
"""Render a tile locally without running the server."""
import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "server"))

from render.image import render_photo  # noqa: E402


def main() -> int:
    p = argparse.ArgumentParser(description="Render a Kindle tile locally.")
    p.add_argument("--tile", choices=["photo"], default="photo")
    p.add_argument("--src", required=True, help="source image path")
    p.add_argument("--out", default="preview.png", help="output PNG path")
    args = p.parse_args()

    out = render_photo(args.src, args.out)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
