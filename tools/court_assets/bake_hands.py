"""Bakes where the performers' hands really were for every mocap gait.

  blender -b --python bake_hands.py -- <scratchpad> <out.json>

Copying joint angles from a mocap performer onto the game's character, whose
torso is longer, leaves the hands about 30 cm too high relative to the hips.
For each locomotion clip this records the hands' positions relative to the
hips, per frame, from the original recording (same frame window build.py cut,
same facing), in the game's axes. The game's arm IK puts the hands there.
"""
import bpy, sys, json, math
from mathutils import Vector, Matrix

S, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
STEP, FPS = 4, 30.0
# game clip -> (recording, first sample, last sample) as build.py chose them
CLIPS = {
    "DribbleRun": ("06_02.bvh", 109, 139),
    "JogM": ("16_36.bvh", 14, 38),
    "Run": ("09_01.bvh", 11, 32),
    "SlideR": ("102_27.bvh", 20, 34),
    "SlideL": ("102_28.bvh", 137, 150),
    "Backpedal": ("06_06.bvh", 38, 69),
}
out = {}
for clip, (bvh, a, b) in CLIPS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_anim.bvh(filepath=S + "/cmu_dl/" + bvh, global_scale=0.0564, rotate_mode='NATIVE',
                            update_scene_fps=False, update_scene_duration=True)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    sc = bpy.context.scene
    head = lambda n: arm.matrix_world @ arm.pose.bones[n].head

    def yaw():
        fwd = (head("LeftUpLeg") - head("RightUpLeg")).cross(Vector((0, 0, 1)))
        return math.atan2(fwd.x, -fwd.y)

    sc.frame_set(1 + STEP * a)
    unyaw = Matrix.Rotation(-yaw(), 4, 'Z')
    hands = {"R": [], "L": []}
    hips_h, lo, hi = [], 9.0, 0.0
    for k in range(a, b + 1):
        sc.frame_set(1 + STEP * k)
        hips = head("Hips")
        floor = min(head("LeftToeBase").z, head("RightToeBase").z)
        hips_h.append(hips.z - floor)
        for side, bone in (("R", "RightHand"), ("L", "LeftHand")):
            rel = unyaw @ (head(bone) - hips)
            hands[side].append([round(rel.x, 4), round(rel.z, 4), round(-rel.y, 4)])
            lo, hi = min(lo, head(bone).z - floor), max(hi, head(bone).z - floor)
    n = b - a  # the last sample closes the loop
    rest = [arm.matrix_world @ bone.head_local for bone in arm.data.bones] + [arm.matrix_world @ bone.tail_local for bone in arm.data.bones]
    stature = max(v.z for v in rest) - min(v.z for v in rest)
    out[clip] = {"length": n / FPS, "samples": n, "hips_height": round(sum(hips_h) / len(hips_h), 4), "stature": round(stature, 4),
                 "hand_r": hands["R"][:n], "hand_l": hands["L"][:n]}
    print("HANDS %-10s %.2fs | performer stands %.2f m | hands at %.0f%%..%.0f%% of his height" % (clip, n / FPS, stature, 100 * lo / stature, 100 * hi / stature))
json.dump(out, open(OUT, "w"), indent=1)
print("HANDS BAKED", len(out), "clips")
