"""Noise stats for every <id>_pose.json: per action, how jumpy the tracked main player is.

main player = largest box in each frame (what the overlay colors cyan).
- id_switch: share of frames where the main player's track id differs from the previous frame
- wrist_jitter: median frame-to-frame wrist move, in % of box height (high = shaky or swapped joints)
- low_conf: share of keypoints with confidence < 0.4 (occluded or guessed)
- empty: share of frames with nobody detected
"""
import glob, json, os, statistics as st, sys
ROOT = "E:/motion-reference/basketball/clips"
rows = {}
for f in sorted(glob.glob(ROOT + "/*/*_pose.json")):
    act = os.path.basename(os.path.dirname(f)); d = json.load(open(f))
    fr = d["frames"]; prev = None; sw = 0; n = 0; jit = []; low = 0; tot = 0; empty = 0; pw = None
    for x in fr:
        if not x["people"]:
            empty += 1; prev = None; pw = None; continue
        p = x["people"][0]; h = max(1.0, p["box"][3] - p["box"][1])
        if prev is not None:
            n += 1; sw += p["id"] != prev
        prev = p["id"]
        kp = p["kp"]; low += sum(k[2] < 0.4 for k in kp); tot += len(kp)
        w = [kp[9], kp[10]]
        if pw is not None:
            for a, b in zip(w, pw):
                if a[2] > 0.4 and b[2] > 0.4:
                    jit.append(100 * ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5 / h)
        pw = w
    r = rows.setdefault(act, [])
    r.append((sw / max(1, n), st.median(jit) if jit else float("nan"), low / max(1, tot), empty / max(1, len(fr)), len(fr)))
out = ["| action | clips | frames | id switch | wrist jitter (% body ht/frame) | low-conf keypoints | no detection |", "|---|---|---|---|---|---|---|"]
for act, r in sorted(rows.items()):
    m = lambda i: st.mean(v[i] for v in r if v[i] == v[i])
    out.append(f"| {act} | {len(r)} | {sum(v[4] for v in r)} | {m(0):.1%} | {m(1):.1f} | {m(2):.0%} | {m(3):.0%} |")
print("\n".join(out))
