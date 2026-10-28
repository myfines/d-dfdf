"""Render a 1024-byte SSD1306 frame dump (one hex byte per line) to PNG."""
import sys
from PIL import Image, ImageDraw

def render(src, dst, title=""):
    data = [int(x.strip(), 16) for x in open(src) if x.strip()]
    if len(data) != 1024:
        raise SystemExit(f"{src}: expected 1024 bytes, got {len(data)}")
    img = Image.new("RGB", (128, 64), (0, 0, 0))
    px = img.load()
    for i, byte in enumerate(data):
        page, col = divmod(i, 128)
        for bit in range(8):
            if byte & (1 << bit):
                px[col, page * 8 + bit] = (120, 230, 255)
    img = img.resize((512, 256), Image.Resampling.NEAREST)
    if title:
        canvas = Image.new("RGB", (512, 288), (8, 8, 12))
        canvas.paste(img, (0, 32))
        d = ImageDraw.Draw(canvas)
        d.text((8, 8), title, fill=(180, 240, 255))
        img = canvas
    img.save(dst)
    print(f"{dst}: {img.size[0]}x{img.size[1]}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit("usage: render_oled.py frame.hex out.png [title]")
    render(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
