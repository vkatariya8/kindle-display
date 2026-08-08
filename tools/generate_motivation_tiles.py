#!/usr/bin/env python3
"""Generate the seven pre-rendered morning tiles installed on the Kindle."""

from pathlib import Path

from render.text import render_quote


MESSAGES = (
    "Begin where you are. Use what you have. Do what you can.",
    "Small, steady steps still take you somewhere meaningful.",
    "Make today useful, then make it beautiful.",
    "Attention is a form of generosity. Give it to what matters.",
    "The work only asks that you return to it.",
    "Leave a little room for delight in the day ahead.",
    "You do not need the whole plan. Just the next honest step.",
)


def main() -> None:
    tile_dir = Path(__file__).resolve().parents[1] / "kindle" / "extensions" / "kindle-display" / "tiles"
    for index, message in enumerate(MESSAGES, start=1):
        render_quote(message, tile_dir / f"motivation-{index}.png")


if __name__ == "__main__":
    main()
