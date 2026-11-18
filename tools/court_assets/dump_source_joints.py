"""Dumps the original recordings' joint positions for comparison with the game.

  blender -b --python dump_source_joints.py -- <scratchpad> <out.json>

Per frame, every major joint in the body frame of the performer (x = his
left, y = up, z = the way he faces), relative to the point on the floor
under his hips, divided by his standing height so bodies of different
sizes compare directly.
"""
import bpy, sys, json, math
from mathutils import Vector, Matrix

S, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
CLIPS = {"JogM": ("16_36.bvh", 14, 38), "DribbleRun": ("06_02.bvh", 109, 139), "Run": ("09_01.bvh", 11, 32),
         "SlideR": ("102_27.bvh", 20, 34), "SlideL": ("102_28.bvh", 137, 150), "Backpedal": ("06_06.bvh", 38, 69)}
JOINTS = {"hips": "Hips", "chest": "Spine1", "neck": "Neck", "head": "Head",
          "l_shoulder": "LeftArm", "l_elbow": "LeftForeArm", "l_wrist": "LeftHand",
          "r_shoulder": "RightArm", "r_elbow": "RightForeArm", "r_wrist": "RightHand",
          "l_hip": "LeftUpLeg", "l_knee": "LeftLeg", "l_ankle": "LeftFoot", "l_toe": "LeftToeBase",
          "r_hip": "RightUpLeg", "r_knee": "RightLeg", "r_ankle": "RightFoot", "r_toe": "RightToeBase"}
out = {}
for clip, (bvh, a, b) in CLIPS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_anim.bvh(filepath=S + "/cmu_dl/" + bvh, global_scale=0.0564, rotate_mode='NATIVE',
                            update_scene_fps=False, update_scene_duration=True)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    sc = bpy.context.scene

    def head(n):
        return arm.matrix_world @ arm.pose.bones[n].head

    rest = [arm.matrix_world @ bn.head_local for bn in arm.data.bones] + [arm.matrix_world @ bn.tail_local for bn in arm.data.bones]
    stature = max(v.z for v in rest) - min(v.z for v in rest)
    sc.frame_set(1 + 4 * a)
    fwd = (head("LeftUpLeg") - head("RightUpLeg")).cross(Vector((0, 0, 1)))
    unyaw = Matrix.Rotation(-math.atan2(fwd.x, -fwd.y), 4, 'Z')
    frames = []
    for k in range(a, b):
        sc.frame_set(1 + 4 * k)
        hips = head("Hips")
        floor = min(head("LeftToeBase").z, head("RightToeBase").z, head("LeftFoot").z, head("RightFoot").z)
        row = {}
        for name, bone in JOINTS.items():
            p = unyaw @ (head(bone) - Vector((hips.x, hips.y, floor)))
            row[name] = [round(p.x / stature, 4), round(p.z / stature, 4), round(-p.y / stature, 4)]
        frames.append(row)
    out[clip] = {"length": (b - a) / 30.0, "stature": stature, "frames": frames}
    print("SOURCE", clip, len(frames), "frames, performer", round(stature, 2), "m")
json.dump(out, open(OUT, "w"))
