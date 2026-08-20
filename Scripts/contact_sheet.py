#!/usr/bin/env python3
"""Tile one screen across every captured locale into a single comparison sheet.

Reviewing copy in seven languages means opening seven files per screen; this puts
them side by side with a language label over each, so wording, length and layout
can be compared at a glance.

Usage:
  Scripts/contact_sheet.py                    # onboarding screens, light pass
  Scripts/contact_sheet.py --all              # every screen
  Scripts/contact_sheet.py --dark             # the -dark capture folders
  Scripts/contact_sheet.py 07_today 09_meds   # named screens

Sheets land in Screenshots/_sheets/<screen>.png (git-ignored with the rest).
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "Screenshots"
OUT = SHOTS / "_sheets"
LOCALES = ["en", "de", "fr", "ja", "es", "it", "pt-BR"]
ONBOARDING = ["00_welcome", "01_howAdd", "02_howAlarm", "03_howProve",
              "04_howToday", "05_howStreak", "06_paywall"]

TILE_W = 420          # per-phone width in the sheet
PAD = 24
LABEL_H = 44
BG = (245, 246, 249)
FG = (24, 24, 28)


def font(size):
    for p in ("/System/Library/Fonts/SFNS.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def build(screen, suffix):
    tiles = []
    for loc in LOCALES:
        p = SHOTS / f"{loc}{suffix}" / f"{screen}.png"
        if p.exists():
            tiles.append((loc, p))
    if not tiles:
        print(f"  skip {screen}: no captures found")
        return

    imgs = []
    for loc, p in tiles:
        im = Image.open(p).convert("RGB")
        im = im.resize((TILE_W, round(im.height * TILE_W / im.width)), Image.LANCZOS)
        imgs.append((loc, im))

    tile_h = max(im.height for _, im in imgs)
    sheet = Image.new("RGB",
                      (len(imgs) * TILE_W + (len(imgs) + 1) * PAD,
                       tile_h + LABEL_H + 2 * PAD),
                      BG)
    draw = ImageDraw.Draw(sheet)
    f = font(26)

    x = PAD
    for loc, im in imgs:
        draw.text((x, PAD), loc, fill=FG, font=f)
        sheet.paste(im, (x, PAD + LABEL_H))
        x += TILE_W + PAD

    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{screen}{suffix}.png"
    sheet.save(dest, optimize=True)
    print(f"  → {dest.relative_to(ROOT)}  ({len(imgs)} locales)")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    suffix = "-dark" if "--dark" in flags else ""

    if args:
        screens = args
    elif "--all" in flags:
        src = SHOTS / f"en{suffix}"
        screens = sorted(p.stem for p in src.glob("*.png"))
    else:
        screens = ONBOARDING

    print(f"Building {len(screens)} sheet(s) from Screenshots/<locale>{suffix}/")
    for s in screens:
        build(s, suffix)


if __name__ == "__main__":
    main()
