from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps

from render import KINDLE_SIZE
from render.text import _wrap_text

FONT_DIR = Path(__file__).resolve().parent.parent / "fonts"
QUOTE_FONT = FONT_DIR / "EBGaramond-Regular.ttf"

_MAX_WIDTH_PCT = 0.8
_MARGIN_PCT = 0.12

_START_PTS = 64
_MIN_PTS = 22
_STEP_PTS = 4


def render_quote_on_background(text: str, bg_path: str | Path, dst_path: str | Path) -> Path:
    """Composite *text* in white onto a darkened greyscale background."""
    bg_path = Path(bg_path)
    dst_path = Path(dst_path)
    canvas_w, canvas_h = KINDLE_SIZE

    # Load background, normalize to greyscale, letterbox to Kindle size.
    with Image.open(bg_path) as bg:
        bg = ImageOps.exif_transpose(bg)
        bg = bg.convert("L")
        bg = ImageOps.pad(bg, KINDLE_SIZE, color=0)

    # Darken so white text pops on e-ink.
    bg = ImageEnhance.Brightness(bg).enhance(0.4)

    max_width = int(canvas_w * _MAX_WIDTH_PCT)
    max_height = int(canvas_h * (1 - 2 * _MARGIN_PCT))

    for size in range(_START_PTS, _MIN_PTS - 1, -_STEP_PTS):
        font = ImageFont.truetype(str(QUOTE_FONT), size)
        lines = _wrap_text(text, font, max_width)

        draw = ImageDraw.Draw(Image.new("L", KINDLE_SIZE, 0))
        rendered = "\n".join(lines)
        bbox = draw.multiline_textbbox((0, 0), rendered, font=font, spacing=0)
        total_height = bbox[3] - bbox[1]

        if total_height <= max_height:
            img = bg.copy()
            draw = ImageDraw.Draw(img)
            x = canvas_w // 2
            y = (canvas_h - total_height) // 2
            draw.multiline_text((x, y), rendered, font=font, fill=255, align="center", anchor="ma")
            dst_path.parent.mkdir(parents=True, exist_ok=True)
            img.save(dst_path, format="PNG", optimize=True)
            return dst_path

    # Fallback: smallest size.
    font = ImageFont.truetype(str(QUOTE_FONT), _MIN_PTS)
    lines = _wrap_text(text, font, max_width)
    img = bg.copy()
    draw = ImageDraw.Draw(img)
    rendered = "\n".join(lines)
    bbox = draw.multiline_textbbox((0, 0), rendered, font=font, spacing=0)
    total_height = bbox[3] - bbox[1]
    x = canvas_w // 2
    y = (canvas_h - total_height) // 2
    draw.multiline_text((x, y), rendered, font=font, fill=255, align="center", anchor="ma")
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst_path, format="PNG", optimize=True)
    return dst_path
