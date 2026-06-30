#!/usr/bin/env python3
"""Generate the kisok-os welcome / boot splash images.

Recreates the IT-Schmiede wordmark (bold "IT" over "SCHMIEDE" with a cyan
bar) and renders a 1920x1080 welcome screen with:

    IT-Schmiede OS System
    Powered by Abdulhalim Alnasani

Outputs:
    assets/logo.png      - the wordmark on a transparent background
    assets/welcome.png   - full-screen welcome / splash (white background)
    assets/welcome-dark.png - dark variant (used by Plymouth)

If you have the *real* logo, drop it in as assets/logo.png and this script
will use it instead of the recreation (run with --use-existing-logo).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

CYAN = (0, 255, 255, 255)
BLACK = (17, 17, 17, 255)

FONT_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def text_size(draw, txt, fnt, stroke=0):
    box = draw.textbbox((0, 0), txt, font=fnt, stroke_width=stroke)
    return box[2] - box[0], box[3] - box[1], box


def draw_centered(draw, cx, y, txt, fnt, fill, stroke=0, stroke_fill=None):
    w, h, box = text_size(draw, txt, fnt, stroke)
    x = cx - w / 2 - box[0]
    draw.text((x - box[0] + (x - x), y - box[1]), txt, font=fnt, fill=fill,
              stroke_width=stroke, stroke_fill=stroke_fill)
    return h


def make_logo(width=1100):
    """Recreate the IT-Schmiede wordmark on a transparent canvas."""
    img = Image.new("RGBA", (width, 760), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = width // 2

    # Heavy weight is faked with a stroke so it reads like Helvetica Black.
    f_it = font(FONT_BOLD, 300)
    f_schmiede = font(FONT_BOLD, 300)

    # "IT" top row
    w_it, h_it, box_it = text_size(d, "IT", f_it, stroke=10)
    d.text((cx - w_it / 2 - box_it[0], 20 - box_it[1]), "IT", font=f_it,
           fill=BLACK, stroke_width=10, stroke_fill=BLACK)

    # "SCHMIEDE" bottom row, scaled to fit width
    txt = "SCHMIEDE"
    size = 300
    while True:
        f_schmiede = font(FONT_BOLD, size)
        w_s, h_s, box_s = text_size(d, txt, f_schmiede, stroke=8)
        if w_s <= width - 20 or size <= 60:
            break
        size -= 4
    y_s = 360
    d.text((cx - w_s / 2 - box_s[0], y_s - box_s[1]), txt, font=f_schmiede,
           fill=BLACK, stroke_width=8, stroke_fill=BLACK)

    # Cyan bar under the wordmark
    bar_y = y_s + h_s + 40
    d.rectangle([cx - w_s / 2, bar_y, cx + w_s / 2, bar_y + 55], fill=CYAN)

    # Trim to content
    bbox = img.getbbox()
    return img.crop(bbox)


def compose(bg_color, text_color, sub_color, out_name, logo):
    W, H = 1920, 1080
    canvas = Image.new("RGBA", (W, H), bg_color)
    d = ImageDraw.Draw(canvas)

    # Scale logo to a comfortable size
    target_w = 900
    scale = target_w / logo.width
    logo_s = logo.resize((target_w, int(logo.height * scale)), Image.LANCZOS)

    logo_x = (W - logo_s.width) // 2
    logo_y = 230
    canvas.alpha_composite(logo_s, (logo_x, logo_y))

    cx = W // 2
    y = logo_y + logo_s.height + 90

    f_title = font(FONT_BOLD, 70)
    w_t, h_t, box_t = text_size(d, "IT-Schmiede OS System", f_title)
    d.text((cx - w_t / 2 - box_t[0], y - box_t[1]), "IT-Schmiede OS System",
           font=f_title, fill=text_color)
    y += h_t + 45

    f_sub = font(FONT_REG, 44)
    sub = "Powered by Abdulhalim Alnasani"
    w_s, h_s, box_s = text_size(d, sub, f_sub)
    d.text((cx - w_s / 2 - box_s[0], y - box_s[1]), sub, font=f_sub,
           fill=sub_color)

    out = os.path.join(ASSETS, out_name)
    canvas.convert("RGB").save(out, "PNG")
    print("wrote", out)


def main():
    os.makedirs(ASSETS, exist_ok=True)
    logo_path = os.path.join(ASSETS, "logo.png")

    if "--use-existing-logo" in sys.argv and os.path.exists(logo_path):
        logo = Image.open(logo_path).convert("RGBA")
        print("using existing", logo_path)
    else:
        logo = make_logo()
        logo.save(logo_path)
        print("wrote", logo_path)

    # White welcome screen
    compose((255, 255, 255, 255), BLACK, (60, 60, 60, 255),
            "welcome.png", logo)
    # Dark variant for the boot splash
    dark_logo = make_logo()
    # invert wordmark to white for dark background, keep cyan bar
    px = dark_logo.load()
    for j in range(dark_logo.height):
        for i in range(dark_logo.width):
            r, g, b, a = px[i, j]
            if a > 0 and (r, g, b) == (17, 17, 17):
                px[i, j] = (255, 255, 255, a)
    compose((10, 12, 16, 255), (255, 255, 255, 255), (180, 180, 180, 255),
            "welcome-dark.png", dark_logo)


if __name__ == "__main__":
    main()
