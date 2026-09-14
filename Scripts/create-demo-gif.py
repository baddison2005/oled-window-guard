#!/usr/bin/env python3
"""Add captions to extracted real recording frames. Requires Pillow."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument('frames', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--title', required=True)
parser.add_argument('--subtitle', required=True)
parser.add_argument('--start', type=float, default=0)
parser.add_argument('--end', type=float, required=True)
parser.add_argument('--fps', type=int, default=3)
parser.add_argument('--speed', type=float, default=1.0)
parser.add_argument('--end-hold', type=float, default=0, help='Extra seconds to hold the final frame')
a = parser.parse_args()
if a.fps <= 0 or a.speed <= 0 or a.end_hold < 0 or a.start < 0 or a.end <= a.start:
    parser.error("Use positive fps/speed, a valid time range and nonnegative end hold.")
font_path = '/System/Library/Fonts/Supplemental/Arial.ttf'
font = lambda size: ImageFont.truetype(font_path, size)
frames = []
for i in range(round(a.start*a.fps), round(a.end*a.fps)):
    path = a.frames / f'{i:04d}.png'
    if not path.exists(): break
    screen = Image.open(path).convert('RGB')
    screen = screen.resize((1280, round(screen.height*1280/screen.width)), Image.Resampling.LANCZOS)
    frame = Image.new('RGB', (1280, screen.height+146), '#101b22')
    frame.paste(screen, (0, 92))
    draw = ImageDraw.Draw(frame)
    draw.text((28, 15), 'OLED WINDOW GUARD', font=font(16), fill='#70e3c8')
    draw.text((28, 43), a.title, font=font(28), fill='#f3f7fa')
    draw.text((28, screen.height+109), a.subtitle, font=font(18), fill='#c2d1da')
    palette = frame.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    frames.append(frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG))
if not frames:
    parser.error("No frames found in the requested time range.")
durations = [max(20, round(1000 / a.fps / a.speed / 10) * 10)] * len(frames)
durations[-1] += round(a.end_hold * 1000 / 10) * 10
a.output.parent.mkdir(parents=True, exist_ok=True)
frames[0].save(a.output, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)
print(f'{a.output}: {len(frames)} frames, {a.output.stat().st_size/1e6:.2f} MB')
