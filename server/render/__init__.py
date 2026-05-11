from pathlib import Path

from PIL import Image

KINDLE_SIZE = (600, 800)


def save_dithered(img: Image.Image, dst_path: str | Path) -> Path:
    """Dither to 1-bit and save as 8-bit greyscale PNG.

    The Kindle Touch's eips refuses 1-bit PNGs ("8bit only" error), so we
    dither to 1-bit then promote back to 8-bit ("L"). The pixels are still
    pure black/white — just stored as 0x00 / 0xFF in an 8-bit container.
    """
    dst_path = Path(dst_path)
    dithered = img.convert("1", dither=Image.FLOYDSTEINBERG)
    out = dithered.convert("L")
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst_path, format="PNG", optimize=True)
    return dst_path
