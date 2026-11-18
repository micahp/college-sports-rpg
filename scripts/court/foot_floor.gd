extends SkeletonModifier3D
## Small contact correction, applied after the animation each frame: if a
## foot's toe or ankle would end up under the floor, lift that foot until
## it rests on it. It only ever raises a foot, by at most MAX_LIFT, and it
## never pins a foot in place, so it cannot hide a clip that is playing at
## the wrong speed or in the wrong direction (the runtime QA measures those
## separately). Retargeted mocap and cross-fades between gaits leave a few
## centimetres of error at the feet; that is all this is for.

const MAX_LIFT: float = 0.06
const SIDES: Array[String] = ["Left", "Right"]

## Height of the floor in the skeleton's space, and how high the toe and
## ankle bones sit above it when the foot is flat (set by the actor).
var floor_y: float = 0.0
var toe_rest: float = 0.012
var ankle_rest: float = 0.08
## Largest lift applied this frame, for QA.
var last_lift: float = 0.0

## Below this rest height a vertex counts as part of the shoe or cuff.
const LOW_VERTS: float = 0.14
## The body is never raised further than this to keep the drawn feet above the floor.
const MAX_BODY_LIFT: float = 0.12

## Second instance, placed after the shoe controls: raises the whole body
## instead of single feet, using the drawn mesh.
var body_mode: bool = false

var _ids: Dictionary = {}
var _low: Array = []  # [bone id, bone-space position, weight] groups per low vertex
var _low_built: bool = false
var _hips: int = -1


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if _ids.is_empty():
		for side: String in SIDES:
			_ids[side] = [sk.find_bone(side + "Foot"), sk.find_bone(side + "Toes")]
	last_lift = 0.0
	if body_mode:
		_lift_body(sk)
		return
	# The skeleton may be scaled or tilted with the model; work in world up.
	var to_world: Transform3D = sk.global_transform
	var up_local: Vector3 = (to_world.basis.inverse() * Vector3.UP).normalized()
	var scale_y: float = to_world.basis.get_scale().y
	for side: String in SIDES:
		var foot: int = _ids[side][0]
		var toe: int = _ids[side][1]
		if foot < 0 or toe < 0:
			continue
		var foot_pose: Transform3D = sk.get_bone_global_pose(foot)
		var toe_pose: Transform3D = sk.get_bone_global_pose(toe)
		var toe_h: float = (to_world * toe_pose.origin).y - floor_y - toe_rest * scale_y
		var ankle_h: float = (to_world * foot_pose.origin).y - floor_y - ankle_rest * scale_y
		var under: float = -minf(toe_h, ankle_h)
		if under <= 0.001:
			continue
		var lift: float = minf(under, MAX_LIFT)
		last_lift = maxf(last_lift, lift)
		foot_pose.origin += up_local * (lift / maxf(scale_y, 0.001))
		sk.set_bone_global_pose(foot, foot_pose)


## The drawn shoe and sock cuff, not just the ankle and toe bones, must stay
## above the floor: a leaning shin carries its cuff under it even when the foot
## bones are fine. Measure the lowest skinned vertex and raise the whole body.
func _lift_body(sk: Skeleton3D) -> void:
	if not _low_built:
		_build_low(sk)
	if _low.is_empty() or _hips < 0:
		return
	var to_world: Transform3D = sk.global_transform
	var poses: Dictionary = {}
	var lowest: float = INF
	for vert: Array in _low:
		var p: Vector3 = Vector3.ZERO
		for inf: Array in vert:
			var b: int = inf[0]
			if not poses.has(b):
				poses[b] = to_world * sk.get_bone_global_pose(b)
			p += (poses[b] as Transform3D) * (inf[1] as Vector3) * float(inf[2])
		lowest = minf(lowest, p.y)
	var under: float = floor_y - lowest
	if under <= 0.002:
		return
	var scale_y: float = maxf(to_world.basis.get_scale().y, 0.001)
	var up_local: Vector3 = (to_world.basis.inverse() * Vector3.UP).normalized()
	var lift: float = minf(under, MAX_BODY_LIFT)
	last_lift = maxf(last_lift, lift)
	var hips: Transform3D = sk.get_bone_global_pose(_hips)
	var shift: Vector3 = up_local * (lift / scale_y)
	hips.origin += shift
	sk.set_bone_global_pose(_hips, hips)
	# Shoe control bones hang off the root, not the hips: move them with it.
	for ctrl: String in ["Foot.L", "Foot.R"]:
		var c: int = sk.find_bone(ctrl)
		if c >= 0:
			var cp: Transform3D = sk.get_bone_global_pose(c)
			cp.origin += shift
			sk.set_bone_global_pose(c, cp)


func _build_low(sk: Skeleton3D) -> void:
	_low_built = true
	_hips = sk.find_bone("Hips")
	sk.force_update_all_bone_transforms()
	_collect_low(sk, sk)
	if _low.is_empty() and sk.get_parent() != null:
		_collect_low(sk, sk.get_parent())


func _collect_low(sk: Skeleton3D, node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).skin != null and (node as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = node
		var skin: Skin = mi.skin
		var mesh: Mesh = mi.mesh
		var binds: Array[int] = []
		for i in skin.get_bind_count():
			var b: int = skin.get_bind_bone(i)
			binds.append(b if b >= 0 else sk.find_bone(skin.get_bind_name(i)))
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty() or verts.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			for v in verts.size():
				var rest: Vector3 = Vector3.ZERO
				var group: Array = []
				for k in per:
					var w: float = wts[v * per + k]
					var bi: int = bones[v * per + k]
					if w <= 0.0 or binds[bi] < 0:
						continue
					var local: Vector3 = skin.get_bind_pose(bi) * verts[v]
					rest += sk.get_bone_global_rest(binds[bi]) * local * w
					group.append([binds[bi], local, w])
				if rest.y < LOW_VERTS and not group.is_empty():
					var tw: float = 0.0
					for g: Array in group:
						tw += float(g[2])
					for g: Array in group:
						g[2] = float(g[2]) / tw
					_low.append(group)
	for c: Node in node.get_children():
		_collect_low(sk, c)
