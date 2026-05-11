from pathlib import Path

from PIL import Image, ImageOps

from render import KINDLE_SIZE, save_dithered


def render_photo(src_path: str | Path, dst_path: str | Path) -> Path:
    src_path = Path(src_path)

    with Image.open(src_path) as im:
        # EXIF orientation: phones save sideways and rely on a tag the Kindle ignores.
        im = ImageOps.exif_transpose(im)
        im = im.convert("L")
        # Letterbox rather than crop so we don't silently lose subject matter.
        # White background matches Kindle's idle background and dithers cleanly.
        fitted = ImageOps.pad(im, KINDLE_SIZE, color=255)

    return save_dithered(fitted, dst_path)
