"""Stick-figure-only reel from <id>_pose.json (no source footage), for the public repo.

Draws exactly what the tracker stored: the 3 largest people per frame, bones where both joints
have conf > 0.4, faint dots for low-confidence joints, and each person's track id, so flicker,
dropped limbs and identity swaps are visible.
usage: python skeleton_reel.py out.mp4 clip1_pose.json[:slow] clip2_pose.json ...
"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont
W, H, SEC = 960, 540, 3.0
SK = [(5,7),(7,9),(6,8),(8,10),(5,6),(5,11),(6,12),(11,12),(11,13),(13,15),(12,14),(14,16),(0,5),(0,6)]
COL = [(0,255,230),(255,0,255),(0,255,0)]
FB = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 24); FS = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 16)
out = sys.argv[1]
ff = subprocess.Popen(["ffmpeg","-v","error","-y","-f","rawvideo","-pix_fmt","rgb24","-s",f"{W}x{H}","-r","30","-i","-",
                       "-c:v","libx264","-crf","26","-preset","slow","-pix_fmt","yuv420p",out], stdin=subprocess.PIPE)
for arg in sys.argv[2:]:
    path, slow = (arg[:-5], True) if arg.endswith(":slow") else (arg, False)
    d = json.load(open(path)); src = d["source"].replace("C:/Users/micah/Videos/motion-reference", "E:/motion-reference")
    sw, sh = map(int, subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=width,height","-of","csv=p=0",src]).decode().split(",")[:2])
    s = min(W/sw, H/sh); ox, oy = (W - sw*s)/2, (H - sh*s)/2
    fps = d["fps"]; frames = [f for f in d["frames"] if f["t"] < SEC]
    act = os.path.basename(os.path.dirname(src)); lab = os.path.basename(path)[:-10]
    rep = 2 if slow else 1; n_out = int(len(frames) / fps * 30 * rep)
    for k in range(n_out):
        f = frames[min(len(frames)-1, int(k / 30 / rep * fps))]
        im = Image.new("RGB", (W, H), (18,18,22)); g = ImageDraw.Draw(im)
        for rank, p in enumerate(f["people"][:3]):
            c = COL[rank]; kp = [(ox + x*s, oy + y*s, cf) for x, y, cf in p["kp"]]
            for a, b in SK:
                if kp[a][2] > 0.4 and kp[b][2] > 0.4: g.line([kp[a][:2], kp[b][:2]], fill=c, width=4)
            for x, y, cf in kp:
                r = 4 if cf > 0.4 else 3; g.ellipse([x-r, y-r, x+r, y+r], fill=c if cf > 0.4 else (90,90,90))
            bx = p["box"]; g.text((ox + bx[0]*s, oy + bx[1]*s - 20), f"id {p['id']}", fill=c, font=FS)
        g.rectangle([0,0,W,36], fill=(0,0,0)); g.text((12,6), f"{act.upper()}  -  {lab}", fill=(255,255,255), font=FB)
        if slow: g.text((12, H-34), "HALF SPEED - watch ids change and joints flicker", fill=(255,220,0), font=FB)
        ff.stdin.write(im.tobytes())
ff.stdin.close(); ff.wait()

