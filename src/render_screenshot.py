#!/usr/bin/env python3
"""
Renders img/statusline.png — a preview image of the statusline output.
Run from the repo root: .venv/bin/python3 src/render_screenshot.py
"""

from PIL import Image, ImageDraw, ImageFont
import re, subprocess, os

BG = "#1e1e2e"
COLORS = {
    "reset": "#cdd6f4", "blue": "#89b4fa", "white": "#cdd6f4",
    "cyan": "#89dceb", "red": "#f38ba8", "green": "#a6e3a1",
    "gray": "#585b70", "magenta": "#f5c2e7", "bright_white": "#ffffff",
}
ANSI_MAP = {
    "0": ("reset", False), "1": (None, True),
    "31": ("red", None), "34": ("blue", None), "36": ("cyan", None),
    "32": ("green", None), "90": ("gray", None),
    "95": ("magenta", None), "97": ("bright_white", None),
}

FONT_SIZE = 22
PAD = 24
LINE_H = FONT_SIZE + 8
EMOJI_NATIVE = 109  # NotoColorEmoji is a bitmap font; only works at this size

reg_font   = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/UbuntuMono[wght].ttf", FONT_SIZE)
bold_font  = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf", FONT_SIZE)
emoji_font = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf", EMOJI_NATIVE)


def split_emoji(text):
    result, buf = [], ""
    for ch in text:
        if ord(ch) >= 0x1F000:
            if buf:
                result.append((buf, False))
                buf = ""
            result.append((ch, True))
        else:
            buf += ch
    if buf:
        result.append((buf, False))
    return result


def parse_ansi(text):
    segs, cur_color, cur_bold = [], COLORS["reset"], False
    for m in re.finditer(r'\x1b\[([0-9;]+)m|((?:(?!\x1b).)+)', text):
        if m.group(1) is not None:
            for code in m.group(1).split(";"):
                if code in ANSI_MAP:
                    ck, bold = ANSI_MAP[code]
                    if bold is True:
                        cur_bold = True
                    elif bold is False:
                        cur_bold = False
                        cur_color = COLORS["reset"]
                    if ck:
                        cur_color = COLORS[ck]
        else:
            segs.append((m.group(2), cur_color, cur_bold))
    return segs


def text_width(text, is_bold):
    font = bold_font if is_bold else reg_font
    w = 0
    for part, emoji in split_emoji(text):
        bb = (emoji_font if emoji else font).getbbox(part)
        w += int((bb[2] - bb[0]) * (LINE_H / EMOJI_NATIVE if emoji else 1)) + (2 if emoji else 0)
    return w


def draw_text(img, draw, x, y, text, color, is_bold):
    font = bold_font if is_bold else reg_font
    for part, emoji in split_emoji(text):
        if emoji:
            bb = emoji_font.getbbox(part)
            ew = bb[2] - bb[0]
            tmp = Image.new("RGBA", (ew + 4, EMOJI_NATIVE + 4), (0, 0, 0, 0))
            ImageDraw.Draw(tmp).text((-bb[0] + 2, -bb[1] + 2), part, font=emoji_font, embedded_color=True)
            nw = max(1, int(ew * (LINE_H / EMOJI_NATIVE)))
            tmp = tmp.resize((nw + 2, LINE_H), Image.LANCZOS)
            img.paste(tmp, (x, y), tmp)
            x += nw + 4
        else:
            draw.text((x, y + 1), part, fill=color, font=font)
            x += font.getbbox(part)[2] - font.getbbox(part)[0]
    return x


def main():
    env = os.environ.copy()
    env["CCBURN_DATA"] = '{"limits":{"session":{"utilization":0.42,"resets_at":"2026-03-09T14:00:00Z"},"weekly":{"utilization":0.17,"resets_at":"2026-03-13T00:00:00Z"}}}'
    env["GIT_BRANCH"] = "main"
    result = subprocess.run(
        ["bash", "src/statusline.sh"],
        input='{"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"used_percentage":28,"context_window_size":200000},"cwd":"/home/developers/Repos/claude-statusline-usage"}',
        capture_output=True, text=True, env=env, cwd=".",
    )
    lines = result.stdout.rstrip("\n").split("\n")
    parsed = [parse_ansi(l) for l in lines]

    img_w = max(sum(text_width(t, b) for t, c, b in s) for s in parsed) + PAD * 2
    img_h = len(lines) * LINE_H + PAD * 2
    img = Image.new("RGB", (img_w, img_h), BG)
    draw = ImageDraw.Draw(img)

    y = PAD
    for segs in parsed:
        x = PAD
        for text, color, is_bold in segs:
            if text:
                x = draw_text(img, draw, x, y, text, color, is_bold)
        y += LINE_H

    os.makedirs("img", exist_ok=True)
    img.save("img/statusline.png")
    print("Saved img/statusline.png")


if __name__ == "__main__":
    main()
