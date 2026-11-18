"""Court asset pipeline (run with Blender, headless).

  blender -b --python build.py -- <scratchpad> <out_dir>

1. Player model: the Quaternius Universal Base male (CC0) with a vertex
   colour mask marking jersey (R), shorts (G) and shoes/socks (B), so the
   game can tint a uniform per team. Exported as player.glb.
2. Basketball clips: CMU mocap BVH files (no usage restrictions) cut to the
   useful window, turned to face forward, made in-place, resampled to 30 fps
   and, for cycles, blended so the loop is seamless. One .glb per clip, on
   the CMU skeleton; Godot retargets them onto the player.
"""
import bpy, sys, math, os
from mathutils import Vector, Matrix, Quaternion

S, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(OUT, exist_ok=True)
FPS_SRC, STEP = 120, 4  # 120 fps mocap -> 30 fps


def export(path, objs, anims):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_animations=anims,
              export_skins=True, export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', export_all_vertex_colors=False, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, os.path.getsize(path))


# ---------------------------------------------------------------- player
def build_player():
    """Body + real clothing geometry + hair.

    The uniform is its own mesh: the torso and hip faces of the body are
    copied, pushed out along their normals (shorts flare toward the hem) and
    skinned with the same weights, so it reads as cloth over the body
    instead of paint. Vertex colour marks jersey (R) and shorts (G) on the
    uniform, shoes (B) on the body.
    """
    import bmesh
    base = S + "/ubc_dl/Universal Base Characters[Standard]"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=base + "/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf")
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.parent is None:
            bpy.data.objects.remove(o)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = bpy.data.objects["SuperHero_Male"]
    me = body.data
    names = {g.index: g.name for g in body.vertex_groups}

    def weights(v):
        return {names[g.group]: g.weight for g in v.groups}

    kind = {}  # vertex index -> "jersey" / "shorts" / "shoes"
    for v in me.vertices:
        w = weights(v)
        z = v.co.z
        torso = sum(w.get(n, 0.0) for n in ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"))
        hips = w.get("pelvis", 0.0) + w.get("thigh_l", 0.0) + w.get("thigh_r", 0.0)
        feet = sum(w.get(n, 0.0) for n in ("foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"))
        arms = sum(w.get(n, 0.0) for n in ("upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"))
        neck = w.get("neck_01", 0.0) + w.get("Head", 0.0)
        if feet > 0.5 or z < 0.13:
            kind[v.index] = "shoes"
        elif (hips > 0.5 and z > 0.52) or (torso > 0.35 and z <= 1.02):
            kind[v.index] = "shorts"
        elif torso > 0.35 and arms < 0.45 and neck < 0.3 and z < 1.53:
            kind[v.index] = "jersey"  # tank top: over the shoulders, arms bare

    def paint(mesh, colour_of):
        for attr in list(mesh.color_attributes):
            mesh.color_attributes.remove(attr)
        col = mesh.color_attributes.new("Uniform", 'BYTE_COLOR', 'CORNER')
        mesh.color_attributes.active_color = col
        mesh.color_attributes.render_color_index = 0
        for loop in mesh.loops:
            col.data[loop.index].color = colour_of(loop.vertex_index)

    # Uniform: a copy of the body's torso and hips, cut to a tank top and
    # shorts with straight edges, smoothed so the cloth hangs flat instead
    # of showing every muscle, then pushed off the skin.
    from mathutils.bvhtree import BVHTree
    bones = arm.data.bones
    region = {}
    for v in me.vertices:
        w = weights(v)
        torso = sum(w.get(n, 0.0) for n in ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"))
        upper = w.get("upperarm_l", 0.0) + w.get("upperarm_r", 0.0)
        if kind.get(v.index) == "shorts":
            region[v.index] = 2
        elif kind.get(v.index) != "shoes" and v.co.z > 0.95 and (torso > 0.15 or (upper > 0.0 and torso > 0.02)):
            region[v.index] = 1  # generous; the cuts below trim it
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.duplicate()
    cloth = bpy.context.view_layer.objects.active
    cloth.name = "Uniform"
    cloth.data.name = "Uniform"
    bm = bmesh.new()
    bm.from_mesh(cloth.data)
    bm.verts.ensure_lookup_table()
    tag = bm.verts.layers.int.new("kind")
    src_layer = bm.verts.layers.int.new("src")
    for v in bm.verts:
        v[tag] = region.get(v.index, 0)
        v[src_layer] = v.index  # which body vertex this cloth vertex came from
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v[tag] == 0], context='VERTS')

    body_bm = bmesh.new()
    body_bm.from_mesh(me)
    body_tree = BVHTree.FromBMesh(body_bm)

    def trim(point, normal, applies):
        """Straight edge without slicing: faces wholly past the plane go,
        and the vertices left past it are slid back onto the plane."""
        def past(v):
            return applies(v) and (v.co - point).dot(normal) > 0.0
        gone = [f for f in bm.faces if all(past(v) for v in f.verts)]
        bmesh.ops.delete(bm, geom=gone, context='FACES')
        for v in bm.verts:
            if past(v):
                v.co -= normal * (v.co - point).dot(normal)

    # Armholes: just past each shoulder joint, square to the arm.
    for side in ("l", "r"):
        joint = bones["upperarm_" + side].head_local.copy()
        along = (bones["lowerarm_" + side].head_local - joint).normalized()
        sign = 1.0 if joint.x > 0 else -1.0
        trim(joint - along * 0.03, along,
             lambda v, j=joint, sg=sign: (v.co.x - j.x) * sg > -0.05 and v.co.z > j.z - 0.14)
    # Neckline: a shallow scoop at the base of the neck.
    neck = bones["neck_01"].head_local.copy()
    up = Vector((0.0, -0.08, 1.0)).normalized()
    trim(neck + Vector((0.0, 0.0, 0.025)), up, lambda v: v.co.z > neck.z - 0.12)
    bm.normal_update()
    # Hang flat: relax the jersey so pecs and abs don't print through, then
    # make sure every cloth point still clears the skin.
    inner = [v for v in bm.verts if v[tag] == 1 and not v.is_boundary]
    for _ in range(8):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        if v[tag] == 1:
            clearance = 0.012  # a fitted jersey, not padding
        else:
            hem = max(0.0, min(1.0, (1.0 - v.co.z) / 0.48))  # 0 at the waist, 1 at the hem
            clearance = 0.010 + 0.005 * hem  # near-straight hem: a wide flare balloons when the knee bends
        co, normal, _i, _d = body_tree.find_nearest(v.co)
        if co is None:
            continue
        height = (v.co - co).dot(normal)  # how far outside the skin this point sits
        if height < clearance:
            v.co += normal * (clearance - height)
    body_bm.free()
    bm.verts.ensure_lookup_table()
    tags = [v[tag] for v in bm.verts]
    srcs = [v[src_layer] for v in bm.verts]
    cloth_tree = BVHTree.FromBMesh(bm)
    boundary = [v.co.copy() for v in bm.verts if v.is_boundary]
    bm.to_mesh(cloth.data)
    bm.free()
    paint(cloth.data, lambda i: (1.0, 0.0, 0.0, 1.0) if tags[i] == 1 else (0.0, 1.0, 0.0, 1.0))
    # A tank top hangs from the torso, not the arm: whatever weight a cloth
    # vertex has on the upper arm moves to that side's clavicle, so the
    # shoulder edge stays put while the arm swings instead of flapping.
    for side in ("l", "r"):
        up = cloth.vertex_groups.get("upperarm_" + side)
        clav = cloth.vertex_groups.get("clavicle_" + side)
        if up is None or clav is None:
            continue
        for v in cloth.data.vertices:
            moved = 0.0
            for g in v.groups:
                if g.group == up.index:
                    moved = g.weight
            if moved > 0.0:
                held = 0.0
                for g in v.groups:
                    if g.group == clav.index:
                        held = g.weight
                clav.add([v.index], held + moved, 'REPLACE')
                up.remove([v.index])
    # Shorts hang from the thigh: weight a vertex has on the calf moves to the
    # thigh, so the hem swings with the leg instead of tucking at the knee.
    for side in ("l", "r"):
        calf = cloth.vertex_groups.get("calf_" + side)
        thigh = cloth.vertex_groups.get("thigh_" + side)
        if calf is None or thigh is None:
            continue
        for v in cloth.data.vertices:
            moved = held = 0.0
            for g in v.groups:
                if g.group == calf.index:
                    moved = g.weight
                elif g.group == thigh.index:
                    held = g.weight
            if moved > 0.0:
                thigh.add([v.index], held + moved, 'REPLACE')
                calf.remove([v.index])
    print("PLAYER uniform verts", len(cloth.data.vertices), "jersey", tags.count(1), "shorts", tags.count(2))

    # Skin under the cloth is removed (kept near the cloth's edges), so
    # nothing can poke through however the body bends or bulks.
    covered = set()
    for v in me.vertices:
        if region.get(v.index) not in (1, 2):
            continue
        hit = cloth_tree.find_nearest(v.co)
        if hit[0] is None or hit[3] > 0.05:
            continue
        if min((v.co - bco).length for bco in boundary) > 0.05:
            covered.add(v.index)
    bm_b = bmesh.new()
    bm_b.from_mesh(me)
    doomed = [f for f in bm_b.faces if all(v.index in covered for v in f.verts)]
    bmesh.ops.delete(bm_b, geom=doomed, context='FACES_ONLY')
    bm_b.to_mesh(me)
    bm_b.free()
    print("PLAYER hid", len(doomed), "skin faces under the uniform")

    # Hair: head-fitted meshes from the pack, skinned to the head bone.
    hairs = []
    for style in ("Hair_Buzzed", "Hair_SimpleParted"):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=base + "/Hairstyles/Origin at 0/glTF (Godot)/" + style + ".gltf")
        for o in set(bpy.data.objects) - before:
            if o.type != 'MESH':
                bpy.data.objects.remove(o)
                continue
            world = o.matrix_world.copy()
            o.parent = arm
            o.matrix_world = world
            o.name = style
            group = o.vertex_groups.new(name="Head")
            group.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
            mod = o.modifiers.new("Armature", 'ARMATURE')
            mod.object = arm
            # Lift the hair 3% off the head so the scalp can't poke through.
            centre = sum((v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)
            for v in o.data.vertices:
                v.co = centre + (v.co - centre) * 1.03
            zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
            print("PLAYER hair", style, "verts", len(o.data.vertices), "z %.2f..%.2f" % (min(zs), max(zs)))
            hairs.append(o)
    # Scalp under each style: body vertices within 3 cm of that hair mesh.
    from mathutils.bvhtree import BVHTree
    under = [set(), set()]
    for n, o in enumerate(hairs[:2]):
        bm_h = bmesh.new()
        bm_h.from_mesh(o.data)
        bm_h.transform(o.matrix_world)
        tree = BVHTree.FromBMesh(bm_h)
        for v in me.vertices:
            if weights(v).get("Head", 0.0) < 0.5:
                continue
            hit = tree.find_nearest(body.matrix_world @ v.co)
            if hit[0] is not None and hit[3] < 0.03:
                under[n].add(v.index)
        bm_h.free()
    print("PLAYER scalp verts under hair", [len(u) for u in under])
    paint(me, lambda i: (1.0 if i in under[0] else 0.0, 1.0 if i in under[1] else 0.0,
                         1.0 if kind.get(i) == "shoes" else 0.0, 1.0))
    # Build: the pack's body is a bodybuilder. The base shape is deflated to
    # a lean college build; the original is kept as the "Bulk" blend shape,
    # so the game can dial muscle from 0 (lean) to 1 (as sculpted).
    def deflate(v):
        w = weights(v)
        g = lambda *names: sum(w.get(n, 0.0) for n in names)
        # Whole body: chest and back, shoulders, arms, glutes, quads, calves, neck.
        return (0.034 * g("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r")
                + 0.017 * g("upperarm_l", "upperarm_r") + 0.012 * g("lowerarm_l", "lowerarm_r")
                + 0.034 * g("thigh_l", "thigh_r") + 0.014 * g("calf_l", "calf_r")
                + 0.028 * g("pelvis") + 0.009 * g("neck_01"))

    full_body = [v.co.copy() for v in me.vertices]
    normals = [v.normal.copy() for v in me.vertices]
    amount = [deflate(v) for v in me.vertices]
    full_cloth = [v.co.copy() for v in cloth.data.vertices]
    for v in me.vertices:
        v.co = full_body[v.index] - normals[v.index] * amount[v.index]
    for v in cloth.data.vertices:
        v.co = full_cloth[v.index] - normals[srcs[v.index]] * amount[srcs[v.index]]
    for obj, full in ((body, full_body), (cloth, full_cloth)):
        obj.shape_key_add(name="Basis")
        key = obj.shape_key_add(name="Bulk")
        for i, co in enumerate(full):
            key.data[i].co = co
        key.value = 0.0
    print("PLAYER lean base, Bulk blend shape; max deflate %.3f m" % max(amount))
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    export(OUT + "/player.glb", [arm] + meshes, False)


# ---------------------------------------------------------------- clips
def facing_yaw(arm):
    """Yaw (about Z) of the body's facing, from the hip line."""
    l = arm.pose.bones["LeftUpLeg"].head
    r = arm.pose.bones["RightUpLeg"].head
    fwd = (l - r).cross(Vector((0, 0, 1)))
    return math.atan2(fwd.x, -fwd.y)  # 0 when facing -Y (Blender front)


def sample(arm, f):
    bpy.context.scene.frame_set(f)
    hips = arm.pose.bones["Hips"]
    return {
        "hips": hips.matrix.copy(),
        "rot": {pb.name: pb.matrix_basis.to_quaternion() for pb in arm.pose.bones},
        "yaw": facing_yaw(arm),
        "lf": arm.pose.bones["LeftFoot"].head.copy(),
        "rf": arm.pose.bones["RightFoot"].head.copy(),
    }


def pose_dist(a, b):
    d = 0.0
    for n in ("LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "Spine"):
        d += 1.0 - abs(a["rot"][n].dot(b["rot"][n]))
    d += abs(a["hips"].translation.z - b["hips"].translation.z) * 0.9
    return d


def make_clip(bvh, name, kind, pick):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_anim.bvh(filepath=S + "/cmu_dl/" + bvh, global_scale=0.0564, rotate_mode='NATIVE', update_scene_fps=False, update_scene_duration=True)
    src = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    n_frames = 1
    with open(S + "/cmu_dl/" + bvh) as fh:
        for line in fh:
            if line.startswith("Frames:"):
                n_frames = int(line.split()[1])
                break
    frames = list(range(1, n_frames + 1, STEP))
    data = [sample(src, f) for f in frames]
    hz = [d["hips"].translation.z for d in data]
    hx = [d["hips"].translation.copy() for d in data]
    fps = FPS_SRC / STEP

    def lateral_speed(i):
        if i == 0:
            return 0.0
        v = (hx[i] - hx[i - 1]) * fps
        yaw = data[i]["yaw"]
        right = Vector((-math.cos(yaw), -math.sin(yaw), 0.0))  # body's right when facing yaw
        return v.dot(right)

    loop = kind == "loop"
    if pick == "peak":  # jump: window around the highest hips point
        k = max(range(len(hz)), key=lambda i: hz[i])
        a, b = max(0, k - int(1.0 * fps)), min(len(data) - 1, k + int(0.55 * fps))
    elif pick in ("slide+", "slide-"):
        sgn = 1.0 if pick == "slide+" else -1.0
        speeds = [lateral_speed(i) * sgn for i in range(len(data))]
        top = max(speeds)
        best, cur = (0, 0), None
        for i, s in enumerate(speeds + [0.0]):
            if s > top * 0.45:
                cur = i if cur is None else cur
            elif cur is not None:
                if i - cur > best[1] - best[0]:
                    best = (cur, i)
                cur = None
        a, b = best[0], best[1] - 1
        print("   slide run %d..%d top speed %.1f" % (a, b, top))
        if b - a > int(0.9 * fps):
            a, b = find_loop(data, a, b, fps)
    elif pick == "mid":  # steady cycle from the middle of the clip
        a, b = find_loop(data, int(len(data) * 0.3), int(len(data) * 0.85), fps)
    elif pick == "hold":  # a held pose: 1.5 s from the middle
        a = int(len(data) * 0.45)
        b = min(len(data) - 1, a + int(1.5 * fps))
    if b - a >= 6:
        # Ground truth for speed matching: how fast the body really travelled.
        travel = (hx[b] - hx[a]) / ((b - a) / fps)
        yaw_a = data[a]["yaw"]
        fwd_axis = Vector((math.sin(yaw_a), -math.cos(yaw_a), 0.0))
        right_axis = Vector((-math.cos(yaw_a), -math.sin(yaw_a), 0.0))
        print("SPEED %s forward %.2f right %.2f m/s" % (name, travel.dot(fwd_axis), travel.dot(right_axis)))
    if b - a < 6:
        print("SKIP %s from %s: no usable window" % (name, bvh))
        return False
    print("CLIP %s from %s: frames %d..%d of %d (%.2fs) peakZ=%.1f" % (name, bvh, a, b, len(data), (b - a) / fps, max(hz)))

    # Destination: same skeleton, fresh keys.
    bpy.ops.object.select_all(action='DESELECT')
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.duplicate()
    dst = bpy.context.view_layer.objects.active
    dst.animation_data_clear()
    dst.name = "Armature"
    for pb in dst.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    yaw0 = data[a]["yaw"]
    unyaw = Matrix.Rotation(-yaw0, 4, 'Z')
    rest_hips = dst.data.bones["Hips"].matrix_local
    floor = min(min(d["lf"].z, d["rf"].z) for d in data[a:b + 1])
    n = b - a + 1
    blend_n = min(6, n // 3) if loop else 0
    scale = 1.0
    for k in range(n):
        d = data[a + k]
        t = 0.0
        if loop and k >= n - blend_n:
            t = (k - (n - blend_n) + 1) / float(blend_n)  # ease the tail into the first frame
        first = data[a]
        for pb in dst.pose.bones:
            q = d["rot"][pb.name]
            if t > 0.0:
                q = q.slerp(first["rot"][pb.name], t)
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=k)
        # Hips: face forward, stay in place (the game moves the player), keep height.
        m = unyaw @ d["hips"]
        z = d["hips"].translation.z
        if t > 0.0:
            z = z + (first["hips"].translation.z - z) * t
            m = (unyaw @ d["hips"]).lerp(unyaw @ first["hips"], t)
        m.translation = Vector((0.0, 0.0, z - floor + (rest_hips.translation.z - 0.0) * 0.0))
        hips = dst.pose.bones["Hips"]
        hips.matrix = m
        bpy.context.view_layer.update()
        hips.keyframe_insert("location", frame=k)
        hips.keyframe_insert("rotation_quaternion", frame=k)
    act = dst.animation_data.action
    act.name = name
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = n - 1
    bpy.context.scene.render.fps = int(fps)
    bpy.data.objects.remove(src)
    export(OUT + "/" + name + ".glb", [dst], True)
    return True


def find_loop(data, a, b, fps):
    """Best (i, j) in [a, b] whose poses match, one or two strides apart."""
    best = (1e9, a, b)
    lo, hi = int(0.45 * fps), int(1.5 * fps)
    for i in range(a, max(a + 1, b - lo)):
        for j in range(i + lo, min(b, i + hi) + 1):
            d = pose_dist(data[i], data[j])
            if d < best[0]:
                best = (d, i, j)
    print("   loop match dist %.4f" % best[0])
    return best[1], best[2]


if "--clips-only" not in sys.argv:
    build_player()
for name, kind, pick, sources in ([] if "--player-only" in sys.argv else [
    ("dribble_run", "loop", "mid", ["06_02.bvh"]),
    ("slide_r", "loop", "slide+", ["102_27.bvh", "102_28.bvh", "102_24.bvh", "102_25.bvh"]),
    ("slide_l", "loop", "slide-", ["102_28.bvh", "102_27.bvh", "102_25.bvh", "102_24.bvh"]),
    ("backpedal", "loop", "mid", ["06_06.bvh"]),
    ("jog", "loop", "mid", ["16_35.bvh"]),
    ("jog_b", "loop", "mid", ["16_36.bvh"]),
    ("jog_c", "loop", "mid", ["02_03.bvh"]),
    ("run", "loop", "mid", ["09_01.bvh"]),
    ("run_b", "loop", "mid", ["09_02.bvh"]),
    ("jumpshot", "once", "peak", ["124_05.bvh"]),
    ("layup", "once", "peak", ["124_06.bvh"]),
]):
    for bvh in sources:
        if make_clip(bvh, name, kind, pick):
            break
print("PIPELINE DONE")
