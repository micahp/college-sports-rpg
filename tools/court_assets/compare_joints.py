"""Recording vs game, joint by joint.

  python compare_joints.py source.json game.json out_dir

For each mocap gait this compares the original recording with the game's
plain retarget ("raw") and with the hand-placement fix ("fixed"):
  - curves over one cycle: elbow bend, shoulder swing, shoulder lift out to
    the side, and wrist height, for each arm
  - side-by-side skeletons, every frame of the cycle, side and front views
  - a printed table of how far each game version is from the recording
All positions are in fractions of standing height, so a 1.45 m performer
and a 1.81 m player compare directly.
"""
import json, math, os, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

src_path, game_path, out_dir = sys.argv[1:4]
os.makedirs(out_dir, exist_ok=True)
source = json.load(open(src_path))
game = json.load(open(game_path))
COLORS = {"recording": "black", "raw": "tab:blue", "fixed": "tab:red"}
LABELS = {"recording": "real recording", "raw": "game: plain retarget", "fixed": "game: with my hand fix"}


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def norm(v):
    return math.sqrt(sum(c * c for c in v))


def angle(a, b):
    d = sum(a[i] * b[i] for i in range(3)) / max(1e-9, norm(a) * norm(b))
    return math.degrees(math.acos(max(-1.0, min(1.0, d))))


def metrics(j, side):
    sh, el, wr = j[side + "_shoulder"], j[side + "_elbow"], j[side + "_wrist"]
    upper = sub(el, sh)
    out_sign = 1.0 if side == "l" else -1.0  # +x is the body's left
    return {
        "elbow bend (deg, 180 = straight)": angle(sub(sh, el), sub(wr, el)),
        "shoulder swing (deg, + = forward)": math.degrees(math.atan2(upper[2], -upper[1])),
        "arm lifted out to the side (deg)": math.degrees(math.atan2(upper[0] * out_sign, -upper[1])),
        "wrist height (% of body height)": wr[1] * 100.0,
    }


def resample(samples, length, n):
    """Game samples (clip time, joints) -> one joint set per recording frame."""
    rows = []
    for k in range(n):
        want = length * k / n
        best = min(samples, key=lambda s: min(abs(s["t"] - want), length - abs(s["t"] - want)))
        rows.append(best["j"])
    return rows


BONES = [("hips", "chest"), ("chest", "neck"), ("neck", "head"),
         ("l_hip", "l_knee"), ("l_knee", "l_ankle"), ("l_ankle", "l_toe"),
         ("r_hip", "r_knee"), ("r_knee", "r_ankle"), ("r_ankle", "r_toe"), ("l_hip", "r_hip"), ("l_shoulder", "r_shoulder")]
ARMS = {"l": [("l_shoulder", "l_elbow"), ("l_elbow", "l_wrist")], "r": [("r_shoulder", "r_elbow"), ("r_elbow", "r_wrist")]}


def draw(ax, j, view):
    hx, hz = j["hips"][0], j["hips"][2]
    def pt(name):
        p = j[name]
        return ((p[2] - hz) if view == "side" else (p[0] - hx), p[1])
    for a, b in BONES:
        (x0, y0), (x1, y1) = pt(a), pt(b)
        ax.plot([x0, x1], [y0, y1], color="0.55", lw=1.6)
    for side, color in (("l", "tab:red"), ("r", "tab:blue")):
        for a, b in ARMS[side]:
            (x0, y0), (x1, y1) = pt(a), pt(b)
            ax.plot([x0, x1], [y0, y1], color=color, lw=2.6)
        ax.plot(*pt(side + "_wrist"), "o", color=color, ms=3.5)
    ax.set_xlim(-0.42, 0.42)
    ax.set_ylim(-0.02, 1.0)
    ax.set_aspect("equal")
    ax.axis("off")


print("clip | joint measure | arm | recording range | plain retarget: range, avg error | with hand fix: range, avg error")
for clip, src in source.items():
    frames = src["frames"]
    n = len(frames)
    series = {"recording": frames}
    for variant in ("raw", "fixed"):
        series[variant] = resample(game[clip][variant], game[clip]["length"], n)
    names = list(metrics(frames[0], "l").keys())
    fig, axes = plt.subplots(len(names), 2, figsize=(13, 3.1 * len(names)), squeeze=False)
    xs = [100.0 * k / n for k in range(n)]
    for r, name in enumerate(names):
        for c, side in enumerate(("l", "r")):
            ax = axes[r][c]
            vals = {}
            for label, rows in series.items():
                vals[label] = [metrics(j, side)[name] for j in rows]
                ax.plot(xs, vals[label], color=COLORS[label], lw=2.2, label=LABELS[label])
            ax.set_title("%s arm: %s" % ("left" if side == "l" else "right", name), fontsize=11)
            ax.set_xlabel("% of the stride")
            ax.grid(alpha=0.3)
            if r == 0 and c == 0:
                ax.legend(fontsize=9)
            rec = vals["recording"]
            parts = []
            for variant in ("raw", "fixed"):
                err = sum(abs(a - b) for a, b in zip(vals[variant], rec)) / n
                parts.append("%.0f..%.0f, off by %.0f" % (min(vals[variant]), max(vals[variant]), err))
            print("%s | %s | %s | %.0f..%.0f | %s | %s" % (clip, name.split(" (")[0], "left" if side == "l" else "right",
                                                           min(rec), max(rec), parts[0], parts[1]))
    fig.suptitle("%s: arm joints over one cycle, real recording vs game" % clip, fontsize=14)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, "curves_%s.png" % clip), dpi=80)
    plt.close(fig)
    # Side-by-side skeletons: every frame of the cycle.
    for view in ("side", "front"):
        fig, axes = plt.subplots(3, n, figsize=(1.25 * n, 7.2), squeeze=False)
        for r, label in enumerate(("recording", "raw", "fixed")):
            for k in range(n):
                draw(axes[r][k], series[label][k], view)
            axes[r][0].set_title(LABELS[label], fontsize=10, loc="left")
        fig.suptitle("%s, %s view, every frame (left arm red, right arm blue). Top: real recording. Middle: plain retarget. Bottom: with my hand fix." % (
            clip, view), fontsize=11)
        fig.tight_layout()
        fig.savefig(os.path.join(out_dir, "skeletons_%s_%s.png" % (clip, view)), dpi=70)
        plt.close(fig)
print("WROTE", out_dir)
