"""Cut reference segments from local source videos into a clip library.

Reads data/animation/basketball_references.json. For each segment whose source
has a local copy under local_root, writes local_root/clips/<action>/<id>.mp4
(frame-accurate re-encode, crop applied if given). With --sheets, also writes
local_root/clips/<action>/<id>_sheet_NN.png: consecutive frames (every --every
frames) left to right, for reading the motion (see the watch-video skill).

Nothing is written inside the repo: the footage is reference only.

usage: python tools/reference/cut_refs.py [--id ID ...] [--action ACTION ...]
                                          [--status frame-read|tagged] [--sheets] [--every 2]
"""
import argparse, glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REG = os.path.join(HERE, "..", "..", "data", "animation", "basketball_references.json")

ap = argparse.ArgumentParser()
ap.add_argument("--id", nargs="*", default=[])
ap.add_argument("--action", nargs="*", default=[])
ap.add_argument("--status", default="")
ap.add_argument("--sheets", action="store_true")
ap.add_argument("--every", type=int, default=2, help="sheet: take every Nth frame")
ap.add_argument("--max", type=float, default=30.0, help="skip segments longer than this (s) unless named by --id")
ap.add_argument("--force", action="store_true")
a = ap.parse_args()

reg = json.load(open(REG, encoding="utf-8"))
root = reg["local_root"]


def local_file(src, t0):
    if "local" in src:
        return os.path.join(root, src["local"]), 0.0
    # partial downloads: pick the part that covers t0; offset = its time zero on the source timeline
    for rel, part in src.get("local_parts", {}).items():
        if part["from"] <= t0 <= part["to"]:
            return os.path.join(root, rel), part["offset"]
    return None, 0.0


def sheet(clip, out_prefix, every):
    from PIL import Image
    tmp = out_prefix + "_f"
    os.makedirs(tmp, exist_ok=True)
    for f in glob.glob(os.path.join(tmp, "*.png")):
        os.remove(f)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", clip, "-vf",
                    f"select='not(mod(n\\,{every}))',scale=300:-1", "-vsync", "vfr",
                    os.path.join(tmp, "%04d.png")], check=True)
    files = sorted(glob.glob(os.path.join(tmp, "*.png")))
    cols, rows = 8, 3
    for n in range(0, len(files), cols * rows):
        chunk = files[n:n + cols * rows]
        w, h = Image.open(chunk[0]).size
        img = Image.new("RGB", (cols * w, rows * h))
        for k, f in enumerate(chunk):
            img.paste(Image.open(f), ((k % cols) * w, (k // cols) * h))
        img.save(f"{out_prefix}_sheet_{n // (cols * rows) + 1:02d}.png")
    for f in files:
        os.remove(f)
    os.rmdir(tmp)


done = 0
for seg in reg["segments"]:
    if a.id and seg["id"] not in a.id:
        continue
    if a.action and seg["action"] not in a.action:
        continue
    if a.status and seg["status"] != a.status:
        continue
    if not a.id and seg["t1"] - seg["t0"] > a.max:
        print("skip (long; name it with --id):", seg["id"])
        continue
    src = reg["sources"][seg["source"]]
    path, offset = local_file(src, seg["t0"])
    if not path or not os.path.exists(path):
        print("no local copy:", seg["id"], src["url"])
        continue
    outdir = os.path.join(root, "clips", seg["action"])
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, seg["id"] + ".mp4")
    if a.force or not os.path.exists(out):
        vf = ["-vf", "crop=" + seg["crop"]] if seg.get("crop") else []
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{seg['t0'] - offset:.3f}",
                        "-to", f"{seg['t1'] - offset:.3f}", "-i", path, *vf, "-an",
                        "-c:v", "libx264", "-crf", "18", "-preset", "veryfast", out], check=True)
    if a.sheets:
        sheet(out, os.path.join(outdir, seg["id"]), a.every)
    print("ok", out)
    done += 1
print(done, "segments")
