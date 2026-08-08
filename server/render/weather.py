from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from render import KINDLE_SIZE, save_dithered


FONT_DIR = Path(__file__).resolve().parent.parent / "fonts"
REGULAR_FONT = FONT_DIR / "EBGaramond-Regular.ttf"
ITALIC_FONT = FONT_DIR / "EBGaramond-Italic.ttf"


def render_weather(forecast: dict[str, float | int | str], dst_path: str | Path) -> Path:
    """Render a compact, legible daily Bangalore forecast tile."""
    img = Image.new("L", KINDLE_SIZE, 255)
    draw = ImageDraw.Draw(img)

    title = ImageFont.truetype(str(REGULAR_FONT), 62)
    subtitle = ImageFont.truetype(str(ITALIC_FONT), 30)
    value = ImageFont.truetype(str(REGULAR_FONT), 68)
    label = ImageFont.truetype(str(REGULAR_FONT), 28)

    draw.text((300, 130), "Bangalore", font=title, fill=0, anchor="mm")
    draw.line((72, 190, 528, 190), fill=0, width=2)

    rows = [
        ("High", f"{forecast['max_temp']:.0f}°C"),
        ("Low", f"{forecast['min_temp']:.0f}°C"),
        ("Wind", f"{forecast['max_wind']:.0f} km/h"),
        ("Rain chance", f"{forecast['rain_chance']:.0f}%"),
    ]
    y = 270
    for label_text, value_text in rows:
        draw.text((92, y), label_text, font=label, fill=0, anchor="lm")
        draw.text((508, y), value_text, font=value, fill=0, anchor="rm")
        y += 115

    draw.text((300, 735), "today's forecast", font=subtitle, fill=0, anchor="mm")
    return save_dithered(img, dst_path)
