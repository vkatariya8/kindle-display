from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from render import KINDLE_SIZE, save_dithered

FONT_DIR = Path(__file__).resolve().parent.parent / "fonts"
QUOTE_FONT = FONT_DIR / "EBGaramond-Regular.ttf"

# Target 90 % canvas width, leave 10 % margin top and bottom.
_MAX_WIDTH_PCT = 0.9
_MARGIN_PCT = 0.1

_START_PTS = 72
_MIN_PTS = 24
_STEP_PTS = 4


def _wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    """Word-wrap text to fit within max_width using the given font."""
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        test = " ".join(current + [word])
        if font.getlength(test) <= max_width:
            current.append(word)
        else:
            if current:
                lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return lines


def render_quote(text: str, dst_path: str | Path) -> Path:
    """Render a quote as a 600×800 greyscale PNG, centred and auto-sized."""
    canvas_w, canvas_h = KINDLE_SIZE
    max_width = int(canvas_w * _MAX_WIDTH_PCT)
    max_height = int(canvas_h * (1 - 2 * _MARGIN_PCT))

    for size in range(_START_PTS, _MIN_PTS - 1, -_STEP_PTS):
        font = ImageFont.truetype(str(QUOTE_FONT), size)
        lines = _wrap_text(text, font, max_width)

        # Measure total block height via multiline bbox.
        draw = ImageDraw.Draw(Image.new("L", KINDLE_SIZE, 255))
        rendered = "\n".join(lines)
        bbox = draw.multiline_textbbox((0, 0), rendered, font=font, spacing=0)
        total_height = bbox[3] - bbox[1]

        if total_height <= max_height:
            img = Image.new("L", KINDLE_SIZE, 255)
            draw = ImageDraw.Draw(img)
            x = canvas_w // 2
            y = (canvas_h - total_height) // 2
            draw.multiline_text((x, y), rendered, font=font, fill=0, align="center", anchor="ma")
            return save_dithered(img, dst_path)

    # Fallback: smallest size, render anyway.
    font = ImageFont.truetype(str(QUOTE_FONT), _MIN_PTS)
    lines = _wrap_text(text, font, max_width)
    img = Image.new("L", KINDLE_SIZE, 255)
    draw = ImageDraw.Draw(img)
    rendered = "\n".join(lines)
    bbox = draw.multiline_textbbox((0, 0), rendered, font=font, spacing=0)
    total_height = bbox[3] - bbox[1]
    x = canvas_w // 2
    y = (canvas_h - total_height) // 2
    draw.multiline_text((x, y), rendered, font=font, fill=0, align="center", anchor="ma")
    return save_dithered(img, dst_path)
