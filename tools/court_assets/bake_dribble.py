"""Bakes ground truth for the dribble from the original mocap recording.

  blender -b --python bake_dribble.py -- <scratchpad> <out.json>

The game's dribble clip is frames 437..557 of CMU 06_02 (a real player
dribbling a real ball). Copying joint angles onto a character with a longer
torso leaves the hands far too high, so this records where the performer's
hands really were relative to his hips, per frame, in the game's axes
(x right-handed like glTF, y up, z = the way he faces). The game uses it to
put the hands back where they were, and to time the ball: release at the
bottom of the hand's push, catch at the top.
"""
import bpy, sys, json, math
from mathutils import Vector, Matrix

S, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
FIRST, LAST, STEP, FPS = 437, 557, 4, 30.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_anim.bvh(filepath=S + "/cmu_dl/06_02.bvh", global_scale=0.0564, rotate_mode='NATIVE',
                        update_scene_fps=False, update_scene_duration=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
sc = bpy.context.scene


def head(name):
    return arm.matrix_world @ arm.pose.bones[name].head


def facing_yaw():
    fwd = (head("LeftUpLeg") - head("RightUpLeg")).cross(Vector((0, 0, 1)))
    return math.atan2(fwd.x, -fwd.y)


sc.frame_set(FIRST)
unyaw = Matrix.Rotation(-facing_yaw(), 4, 'Z')
hands = {"R": [], "L": []}
heights = []
hips_h = []
for f in range(FIRST, LAST + 1, STEP):
    sc.frame_set(f)
    hips = head("Hips")
    floor = min(head("LeftToeBase").z, head("RightToeBase").z)
    for side, bone in (("R", "RightHand"), ("L", "LeftHand")):
        rel = unyaw @ (head(bone) - hips)
        hands[side].append([round(rel.x, 4), round(rel.z, 4), round(-rel.y, 4)])  # Blender -> game axes
    heights.append(head("RightHand").z - floor)
    hips_h.append(hips.z - floor)
n = len(heights) - 1  # the last sample closes the loop
length = n / FPS
# Turning points of the dribbling hand (cyclic over the loop).
smooth = [sum(heights[(i + k) % n] for k in (-1, 0, 1)) / 3.0 for i in range(n)]
turns = []
for i in range(n):
    a, b, c = smooth[(i - 1) % n], smooth[i], smooth[(i + 1) % n]
    near = [smooth[(i + k) % n] for k in range(-5, 6)]
    kind = ""
    if b >= a and b > c and b - min(near) > 0.03 and b >= max(near) - 1e-6:
        kind = "top"
    elif b <= a and b < c and max(near) - b > 0.03 and b <= min(near) + 1e-6:
        kind = "bottom"
    if kind and (not turns or turns[-1][1] != kind):
        turns.append((i, kind))
if len(turns) >= 2 and turns[0][1] == turns[-1][1]:
    turns.pop()
flights = []
for k, (i, kind) in enumerate(turns):
    j, kind2 = turns[(k + 1) % len(turns)]
    if kind == "bottom" and kind2 == "top":
        span = ((j - i) % n) / FPS
        flights.append({"t0": i / FPS, "span": span, "p0": hands["R"][i], "p1": hands["R"][j],
                        "release_height": round(heights[i], 3), "catch_height": round(heights[j], 3)})
print("TRUTH loop %.2fs | hips %.2f m | dribbling hand %.2f..%.2f m above the floor" % (length, sum(hips_h) / len(hips_h), min(heights), max(heights)))
print("TRUTH turning points", turns)
for fl in flights:
    print("TRUTH ball leaves the hand at %.2fs (hand %.2f m), back in the hand %.2fs later (hand %.2f m); hand on the ball %.2fs" % (
        fl["t0"], fl["release_height"], fl["span"], fl["catch_height"], length / max(1, len(flights)) - fl["span"]))
rest = [arm.matrix_world @ bone.head_local for bone in arm.data.bones] + [arm.matrix_world @ bone.tail_local for bone in arm.data.bones]
stature = max(v.z for v in rest) - min(v.z for v in rest)
print("TRUTH performer stands %.2f m: hand at %.0f%% of his height at release, %.0f%% at the catch" % (stature, 100 * min(heights) / stature, 100 * max(heights) / stature))
json.dump({"clip": "DribbleRun", "length": length, "side": "R", "radius": 0.12, "samples": n, "stature": round(stature, 4),
           "hips_height": round(sum(hips_h) / len(hips_h), 4),
           "hand_r": hands["R"][:n], "hand_l": hands["L"][:n], "flights": flights}, open(OUT, "w"), indent=1)
print("TRUTH BAKED", len(flights), "dribble(s) per loop")
