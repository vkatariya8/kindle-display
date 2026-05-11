from pathlib import Path

from PIL import Image, ImageOps

KINDLE_SIZE = (600, 800)


def render_photo(src_path: str | Path, dst_path: str | Path) -> Path:
    src_path = Path(src_path)
    dst_path = Path(dst_path)

    with Image.open(src_path) as im:
        # EXIF orientation: phones save sideways and rely on a tag the Kindle ignores.
        im = ImageOps.exif_transpose(im)
        im = im.convert("L")
        # Letterbox rather than crop so we don't silently lose subject matter.
        # White background matches Kindle's idle background and dithers cleanly.
        fitted = ImageOps.pad(im, KINDLE_SIZE, color=255)
        # Floyd–Steinberg dither hides banding on this 4-bit panel.
        # We dither to 1-bit then promote back to 8-bit ("L") because the
        # Kindle Touch's eips refuses 1-bit PNGs ("8bit only" error).
        # The pixels are still pure black/white — just stored as 0x00 / 0xFF
        # in an 8-bit greyscale container.
        dithered = fitted.convert("1", dither=Image.FLOYDSTEINBERG)
        out = dithered.convert("L")

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst_path, format="PNG", optimize=True)
    return dst_path
