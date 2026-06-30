#!/usr/bin/env python3
"""Generate the isolinux/syslinux boot-menu background for kisok-os.

Produces a 640x480 PNG branded with the IT-Schmiede logo (top half) and a
dark lower area kept clear for the boot menu text. Also emits an SVG wrapper
that embeds the PNG, because live-build renders the bootloader background from
splash.svg.

Outputs:
    assets/boot-splash.png
    config/bootloaders/isolinux/splash.svg   (embeds the PNG)
"""
import base64
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
ISOLINUX = os.path.join(ROOT, "config", "bootloaders", "isolinux")

FONT_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
BG = (10, 12, 16)
CYAN = (0, 255, 255)

W, H = 640, 480


def text_w(d, s, f):
    b = d.textbbox((0, 0), s, font=f)
    return b[2] - b[0]


def main():
    os.makedirs(ISOLINUX, exist_ok=True)
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # Logo wordmark (reuse the transparent recreation if present)
    logo_path = os.path.join(ASSETS, "logo.png")
    if os.path.exists(logo_path):
        logo = Image.open(logo_path).convert("RGBA")
        # white version on dark bg
        px = logo.load()
        for j in range(logo.height):
            for i in range(logo.width):
                r, g, b, a = px[i, j]
                if a > 0 and (r, g, b) == (17, 17, 17):
                    px[i, j] = (255, 255, 255, a)
        target_w = 300
        scale = target_w / logo.width
        logo = logo.resize((target_w, int(logo.height * scale)), Image.LANCZOS)
        img.paste(logo, ((W - logo.width) // 2, 30), logo)
        y = 30 + logo.height + 18
    else:
        y = 60

    f_title = ImageFont.truetype(FONT_BOLD, 30)
    t = "IT-Schmiede OS System"
    d.text(((W - text_w(d, t, f_title)) // 2, y), t, font=f_title,
           fill=(255, 255, 255))
    y += 40

    f_sub = ImageFont.truetype(FONT_REG, 18)
    s = "Powered by Abdulhalim Alnasani"
    d.text(((W - text_w(d, s, f_sub)) // 2, y), s, font=f_sub,
           fill=(150, 150, 150))

    png_path = os.path.join(ASSETS, "boot-splash.png")
    img.save(png_path)
    print("wrote", png_path)

    # SVG wrapper embedding the PNG (live-build renders splash.svg -> png).
    with open(png_path, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode("ascii")
    svg = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
        f'  <image width="{W}" height="{H}" '
        f'xlink:href="data:image/png;base64,{b64}"/>\n'
        '</svg>\n'
    )
    svg_path = os.path.join(ISOLINUX, "splash.svg")
    with open(svg_path, "w") as fh:
        fh.write(svg)
    print("wrote", svg_path)


if __name__ == "__main__":
    main()
