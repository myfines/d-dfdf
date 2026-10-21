"""Render 1024 page-ordered hex bytes emitted by tb_oled_scope (+FRAME=...)."""
import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = [int(word, 16) for word in args.source.read_text().split()]
    if len(data) != 1024 or any(not 0 <= value <= 255 for value in data):
        parser.error("expected exactly 1024 bytes")
    image = Image.new("RGB", (128, 64), (2, 9, 14))
    for page in range(8):
        for column in range(128):
            for bit in range(8):
                if data[page * 128 + column] >> bit & 1:
                    image.putpixel((column, page * 8 + bit), (110, 235, 255))
    image.resize((768, 384), Image.Resampling.NEAREST).save(args.output)


if __name__ == "__main__":
    main()
