"""Labeled overview: one frame every --step seconds, time printed on each cell.

usage: python time_index.py video.mp4 out_dir --step 4 [--start 0 --end N] [--cols 10 --rows 6 --cell 240]
"""
import argparse, os, subprocess, glob
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("video"); ap.add_argument("out")
ap.add_argument("--step", type=float, default=4.0)
ap.add_argument("--start", type=float, default=0.0); ap.add_argument("--end", type=float, default=0.0)
ap.add_argument("--cols", type=int, default=10); ap.add_argument("--rows", type=int, default=6)
ap.add_argument("--cell", type=int, default=240)
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                     "-of", "csv=p=0", a.video]).decode().strip())
end = a.end or dur
tmp = os.path.join(a.out, "_f")
os.makedirs(tmp, exist_ok=True)
for f in glob.glob(os.path.join(tmp, "*.jpg")):
    os.remove(f)
# one decode pass: fps filter picks a frame every step seconds
subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(a.start), "-to", str(end), "-i", a.video,
                "-vf", f"fps=1/{a.step},scale={a.cell}:-1", os.path.join(tmp, "%05d.jpg")], check=True)
files = sorted(glob.glob(os.path.join(tmp, "*.jpg")))
try:
    font = ImageFont.truetype("arial.ttf", 16)
except OSError:
    font = ImageFont.load_default()
per = a.cols * a.rows
for n in range(0, len(files), per):
    chunk = files[n:n + per]
    h = Image.open(chunk[0]).height
    sheet = Image.new("RGB", (a.cols * a.cell, a.rows * h), "black")
    d = ImageDraw.Draw(sheet)
    for k, f in enumerate(chunk):
        t = a.start + (n + k) * a.step
        x, y = (k % a.cols) * a.cell, (k // a.cols) * h
        sheet.paste(Image.open(f), (x, y))
        lab = f"{t:.0f}"
        d.rectangle([x, y, x + 10 * len(lab) + 6, y + 19], fill="black")
        d.text((x + 3, y + 1), lab, fill="yellow", font=font)
    sheet.save(os.path.join(a.out, f"t_{n // per + 1:02d}.png"))
print(len(files), "frames")
