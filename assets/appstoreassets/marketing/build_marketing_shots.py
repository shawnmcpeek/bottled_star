#!/usr/bin/env python3
"""Compose captioned marketing screenshots from gameplay dumps."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "assets" / "appstoreassets"
FONTS = ROOT / "assets" / "fonts"
OUT = ASSETS / "marketing"

SPACE = (5, 3, 8)
SCORE = (255, 240, 212)
GOLD = (232, 192, 120)

SIZES = {
    "play_phone": (1080, 1920),
    "iphone_63": (1206, 2622),
    "ipad_13": (2048, 2732),
}

SHOTS = [
    {
        "src": ASSETS / "iosscreenshots" / "IMG_0215.png",
        "headline": "Climb to iron",
        "sub": "Fuse up the stellar ladder",
        "crop_top": 96,
    },
    {
        "src": ASSETS / "iosscreenshots" / "IMG_0216.png",
        "headline": "Aim · Charge · Inject",
        "sub": "Hold a star in a bottle",
        "crop_top": 96,
    },
    {
        "src": ASSETS / "iosscreenshots" / "IMG_0217.png",
        "headline": "Collapse mode",
        "sub": "Remnants refuse to fuse",
        "crop_top": 96,
    },
    {
        "src": ASSETS / "androidscreenshots" / "Screenshot_20260808_162305.jpg",
        "headline": "Score by kilonovas",
        "sub": "Then let it go quiet",
        "crop_top": 72,
        "crop_bottom": 96,
    },
    {
        "src": ASSETS / "iosscreenshots" / "IMG_0218.png",
        "headline": "Real fusion physics",
        "sub": "Not random candy merges",
        "crop_top": 96,
    },
]


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size=size)


def fit_cover(img: Image.Image, box: tuple[int, int]) -> Image.Image:
    tw, th = box
    scale = max(tw / img.width, th / img.height)
    nw, nh = int(img.width * scale), int(img.height * scale)
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def prepare_source(path: Path, crop_top: int = 0, crop_bottom: int = 0) -> Image.Image:
    img = Image.open(path).convert("RGB")
    bottom = img.height - crop_bottom if crop_bottom else img.height
    return img.crop((0, crop_top, img.width, bottom))


def wrap_text(
    draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, max_w: int
) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = word if not cur else f"{cur} {word}"
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def compose(shot: dict, canvas_size: tuple[int, int]) -> Image.Image:
    w, h = canvas_size
    band = int(h * 0.22)
    gameplay_h = h - band

    src = prepare_source(
        shot["src"],
        crop_top=shot.get("crop_top", 0),
        crop_bottom=shot.get("crop_bottom", 0),
    )
    gameplay = fit_cover(src, (w, gameplay_h))

    # Blurred gameplay bleed behind the caption band
    bleed = gameplay.crop((0, 0, w, min(160, gameplay_h))).resize((w, band))
    bleed = bleed.filter(ImageFilter.GaussianBlur(32))
    dark = Image.new("RGB", (w, band), SPACE)
    band_img = Image.blend(bleed, dark, 0.84)

    canvas = Image.new("RGB", (w, h), SPACE)
    canvas.paste(band_img, (0, 0))
    canvas.paste(gameplay, (0, band))

    draw = ImageDraw.Draw(canvas, "RGBA")
    rule_y = band - max(4, h // 400)
    draw.line(
        [(int(w * 0.14), rule_y), (int(w * 0.86), rule_y)],
        fill=GOLD + (210,),
        width=max(2, h // 900),
    )

    head_size = max(42, int(w * 0.078))
    sub_size = max(22, int(w * 0.038))
    brand_size = max(16, int(w * 0.028))
    head_font = load_font("SpaceGrotesk-Bold.ttf", head_size)
    sub_font = load_font("SpaceGrotesk-Medium.ttf", sub_size)
    brand_font = load_font("SpaceGrotesk-SemiBold.ttf", brand_size)

    max_text_w = int(w * 0.86)
    head_lines = wrap_text(draw, shot["headline"], head_font, max_text_w)
    sub_lines = wrap_text(draw, shot["sub"], sub_font, max_text_w)

    line_gap = int(head_size * 0.12)
    sub_gap = int(sub_size * 0.18)
    block_h = (
        len(head_lines) * head_size
        + max(0, len(head_lines) - 1) * line_gap
        + int(head_size * 0.35)
        + len(sub_lines) * sub_size
        + max(0, len(sub_lines) - 1) * sub_gap
    )
    y = max(int(h * 0.03), (band - block_h) // 2 - int(h * 0.008))

    for line in head_lines:
        tw = draw.textlength(line, font=head_font)
        draw.text(((w - tw) / 2, y), line, font=head_font, fill=SCORE)
        y += head_size + line_gap
    y += int(head_size * 0.18)
    for line in sub_lines:
        tw = draw.textlength(line, font=sub_font)
        draw.text(((w - tw) / 2, y), line, font=sub_font, fill=(232, 201, 160))
        y += sub_size + sub_gap

    brand = "BOTTLED STAR"
    tw = draw.textlength(brand, font=brand_font)
    draw.text(
        ((w - tw) / 2, h - brand_size - int(h * 0.032)),
        brand,
        font=brand_font,
        fill=GOLD,
    )

    return canvas.convert("RGB")


def main() -> None:
    for size_name, dims in SIZES.items():
        out_dir = OUT / size_name
        out_dir.mkdir(parents=True, exist_ok=True)
        for i, shot in enumerate(SHOTS, start=1):
            frame = compose(shot, dims)
            path = out_dir / f"{i:02d}.jpg"
            frame.save(path, "JPEG", quality=92, optimize=True, dpi=(72, 72))
            print(f"wrote {path} {frame.size}")


if __name__ == "__main__":
    main()
