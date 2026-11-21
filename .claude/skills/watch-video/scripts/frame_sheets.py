"""Lay out consecutive frames of a video (or a numbered image folder) as contact sheets.

Frames run left to right, top to bottom, with no gaps, so a sheet reads like
a flipbook. Needs ffmpeg and ffprobe on PATH.

  python frame_sheets.py clip.mp4 out_dir --start 2.0 --duration 0.8 --crop 400:400:300:150
  python frame_sheets.py frames_dir out_dir --pattern "f_%04d.png" --fps 30 --start 1.0 --duration 1.0
"""
import argparse
import math
import os
import subprocess
import sys


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def probe_fps(path):
    r = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate",
             "-of", "default=nw=1:nk=1", path])
    try:
        num, den = r.stdout.strip().split("/")
        return float(num) / float(den)
    except Exception:
        return 30.0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="video file, or a folder of numbered images (with --pattern)")
    ap.add_argument("out_dir")
    ap.add_argument("--start", type=float, default=0.0, help="window start, seconds")
    ap.add_argument("--duration", type=float, default=1.0, help="window length, seconds")
    ap.add_argument("--step", type=int, default=1, help="take every Nth frame (1 = every frame)")
    ap.add_argument("--crop", default="", help="W:H:X:Y in source pixels, to zoom on the subject")
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--rows", type=int, default=3)
    ap.add_argument("--cell-width", type=int, default=360)
    ap.add_argument("--pattern", default="", help="image name pattern when source is a folder, e.g. f_%%04d.png")
    ap.add_argument("--fps", type=float, default=0.0, help="frame rate for an image folder (default 30)")
    ap.add_argument("--first-number", type=int, default=1, help="number of the first image in a folder")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    is_folder = os.path.isdir(args.source)
    if is_folder and not args.pattern:
        sys.exit("a folder source needs --pattern, e.g. --pattern f_%04d.png")
    fps = args.fps or (30.0 if is_folder else probe_fps(args.source))
    first = int(round(args.start * fps))
    count = max(1, int(round(args.duration * fps)))
    picked = math.ceil(count / args.step)
    per_sheet = args.cols * args.rows
    sheets = math.ceil(picked / per_sheet)

    filters = []
    if args.step > 1:
        filters.append("select='not(mod(n\\,%d))'" % args.step)
    if args.crop:
        filters.append("crop=" + args.crop)
    filters.append("scale=%d:-2" % args.cell_width)
    filters.append("tile=%dx%d" % (args.cols, args.rows))
    vf = ",".join(filters)

    if is_folder:
        inp = ["-start_number", str(args.first_number + first), "-i", os.path.join(args.source, args.pattern)]
        limit = ["-frames:v", str(sheets)]
        pre = ["-framerate", str(fps)]
        frame_limit = []
        # an image sequence has no timestamps to seek, so cap how many inputs are read
        cap = ["-vframes", str(sheets)]
        cmd = ["ffmpeg", "-y", "-loglevel", "error"] + pre + inp + ["-vf", vf, "-vsync", "0"] + cap + [
            os.path.join(args.out_dir, "sheet_%02d.png")]
    else:
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.4f" % args.start, "-t", "%.4f" % args.duration,
               "-i", args.source, "-vf", vf, "-vsync", "0", os.path.join(args.out_dir, "sheet_%02d.png")]
    r = run(cmd)
    if r.returncode != 0:
        sys.exit("ffmpeg failed: " + r.stderr.strip()[-600:])
    made = sorted(f for f in os.listdir(args.out_dir) if f.startswith("sheet_") and f.endswith(".png"))
    print("fps %.2f | frames %d..%d (%d frames, every %d) | %d per sheet, read left to right, top to bottom"
          % (fps, first, first + count - 1, picked, args.step, per_sheet))
    print("each frame is %.3f s after the one before" % (args.step / fps))
    for f in made:
        print(os.path.join(args.out_dir, f))


if __name__ == "__main__":
    main()
