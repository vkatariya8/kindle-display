from pathlib import Path

from PIL import Image, ImageOps

from render import KINDLE_SIZE


def render_photo(src_path: str | Path, dst_path: str | Path) -> Path:
    src_path = Path(src_path)
    dst_path = Path(dst_path)

    with Image.open(src_path) as im:
        # EXIF orientation: phones save sideways and rely on a tag the Kindle ignores.
        im = ImageOps.exif_transpose(im)
        im = im.convert("L")
        # Letterbox rather than crop so we don't silently lose subject matter.
        # White background matches Kindle's idle background.
        fitted = ImageOps.pad(im, KINDLE_SIZE, color=255)

    # Save as true 8-bit greyscale — the Kindle Touch panel has 16 native
    # grey levels, so keeping tonal range looks far better than forcing
    # everything to pure black/white via 1-bit dither.
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    fitted.save(dst_path, format="PNG", optimize=True)
    return dst_path
