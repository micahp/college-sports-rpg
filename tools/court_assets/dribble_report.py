"""Reads a court_dribble_qa log and compares each steady dribble with the real recording."""
import re, sys, json
K = 1.81 / json.load(open(sys.argv[2]))["stature"] if len(sys.argv) > 2 else 1.0
REL, CATCH = 0.77 * K, 1.03 * K
seg = None; rows = {}; cur = None
for line in open(sys.argv[1], encoding="utf-8", errors="ignore"):
    m = re.match(r"SEG (.+)", line)
    if m:
        seg = m.group(1).strip(); rows[seg] = []; cur = None; continue
    m = re.match(r"DRIB hand on the ball ([\d.]+)s, then released at ([\d.]+) m \| gait (\w*) at ([\d.]+) m/s, clip rate ([\d.]+)", line)
    if m and seg:
        cur = {"on": float(m.group(1)), "rel": float(m.group(2)) + 0.13, "gait": m.group(3), "rate": float(m.group(5))}
        rows[seg].append(cur); continue
    m = re.match(r"DRIB\s+ball away ([\d.]+)s, caught at ([\d.]+) m", line)
    if m and cur is not None:
        cur["away"] = float(m.group(1)); cur["catch"] = float(m.group(2)) + 0.13
print("truth: hand on ball 0.40 s, ball away 0.60 s (both divided by playback rate); hand %.2f m at release, %.2f m at catch (performer's 0.77 and 1.03 m scaled to this player's height)" % (REL, CATCH))
print("segment     | gait       | rate | dribbles | per second | hand on ball (real) | ball away (real) | hand at release | at catch | verdict")
fails = 0
for seg, rs in rows.items():
    rs = [r for r in rs[2:] if "away" in r]  # skip the first two while he settles
    if not rs:
        print("%-11s | no steady dribbles logged  <-- FAIL" % seg); fails += 1; continue
    avg = lambda k: sum(r[k] for r in rs) / len(rs)
    rate = avg("rate")
    on, away = avg("on"), avg("away")
    spread = max(r["on"] for r in rs) - min(r["on"] for r in rs)
    why = []
    if abs(on - 0.40 / rate) > 0.06: why.append("hand-on time off")
    if abs(away - 0.60 / rate) > 0.06: why.append("ball-away time off")
    if spread > 0.08: why.append("uneven rhythm")
    if abs(avg("rel") - REL) > 0.08: why.append("release height off")
    if abs(avg("catch") - CATCH) > 0.08: why.append("catch height off")
    fails += bool(why)
    print("%-11s | %-10s | %.2f | %8d | %.2f       | %.2f s (%.2f)       | %.2f s (%.2f)    | %.2f m          | %.2f m   | %s" % (
        seg, rs[-1]["gait"], rate, len(rs), 1.0 / (on + away), on, 0.40 / rate, away, 0.60 / rate, avg("rel"), avg("catch"),
        "pass" if not why else "FAIL: " + ", ".join(why)))
print("DRIBBLE QA:", "PASSED" if fails == 0 else "%d segment(s) FAIL" % fails)
