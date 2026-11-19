class_name CourtPlayerModel
extends RefCounted
## Builds a court player: the standard-skeleton base character
## (assets/court/player.glb) with a cloth uniform mesh, hair, and one
## AnimationPlayer holding every court clip. Locomotion clips come from the
## animation library that shares the model's skeleton; basketball clips are
## CMU mocap retargeted by the engine at import (bone maps in assets/court).

const MODEL: String = "res://assets/court/player.glb"
const UAL: String = "res://assets/court/ual_standard.glb"
const HAIR_STYLES: Array[String] = ["Hair_Buzzed", "Hair_SimpleParted"]
## clip name in game -> [source file, animation name in that file, loops, is mocap]
const CLIPS: Dictionary = {
	"Idle": [UAL, "Idle", true, false],
	"Walk": [UAL, "Walk", true, false],
	"Jog": [UAL, "Jog_Fwd", true, false],
	"Sprint": [UAL, "Sprint", true, false],
	"Jump": [UAL, "Jump_Start", false, false],
	"Clap": [UAL, "Interact", false, false],
	"Reach": [UAL, "Interact", false, false],
	"Pass": [UAL, "Push", false, false],
	"DribbleRun": ["res://assets/court/dribble_run.glb", "dribble_run", true, true],
	"SlideL": ["res://assets/court/slide_l.glb", "slide_l", true, true],
	"SlideR": ["res://assets/court/slide_r.glb", "slide_r", true, true],
	"Backpedal": ["res://assets/court/backpedal.glb", "backpedal", true, true],
	"JogM": ["res://assets/court/jog.glb", "jog_b", true, true],
	"Run": ["res://assets/court/run.glb", "run", true, true],
	"JumpShot": ["res://assets/court/jumpshot.glb", "jumpshot", false, true],
	"Layup": ["res://assets/court/layup.glb", "layup", false, true],
}

const GROUND_OFFSETS: Dictionary = {"DribbleRun": -0.004, "JumpShot": -0.004, "Layup": -0.006, "SlideL": 0.048, "SlideR": 0.016, "JogM": 0.041, "Run": -0.040}

## Ground speed (m/s) each loop was recorded or authored at. Mocap values
## are the performer's measured travel; library values come from its
## root-motion file. Playback is scaled by actual speed / this, so a planted
## foot stays planted.
const CLIP_SPEED: Dictionary = {"Walk": 0.97, "JogM": 2.68, "Run": 3.60, "Jog": 5.36, "Sprint": 8.25,
	"DribbleRun": 1.43, "SlideR": 2.63, "SlideL": 2.24, "Backpedal": 1.22}

## When the left foot lands in each loop (seconds into the clip). Every loop
## holds one stride, so a gait switch can start the new clip at the same
## point in the stride as the old one. Measured by tests/court_model_view.
const CLIP_STRIKE: Dictionary = {"Walk": 0.100, "JogM": 0.223, "Run": 0.315, "Jog": 0.027, "DribbleRun": 0.325,
	"SlideL": 0.320, "SlideR": 0.029, "Backpedal": 0.741}
## Which way each loop travels in the body's frame (x = right, y = forward).
const CLIP_DIR: Dictionary = {"Walk": Vector2(0, 1), "JogM": Vector2(0, 1), "Run": Vector2(0, 1),
	"Jog": Vector2(0, 1), "DribbleRun": Vector2(0, 1), "SlideL": Vector2(-1, 0), "SlideR": Vector2(1, 0),
	"Backpedal": Vector2(0, -1)}

## The game's own campus students (assets/characters) as court players: the
## same model the rest of the game uses, retargeted to the court's clips.
const STUDENT: String = "res://assets/court/students/Male_Casual.fbx"
## Basketball mocap retargeted onto the student by MocapRetarget instead of the
## engine's import retarget (which folds the chest on these and drops the jump).
const Retarget = preload("res://scripts/court/mocap_retarget.gd")
const RETARGETED: Array[String] = ["JumpShot", "Layup", "DribbleRun", "SlideL", "SlideR", "Backpedal"]
## Off: those clips keep the engine's import retarget (for side-by-side checks).
static var mocap_retarget: bool = true
static var students: bool = true
static var _library: AnimationLibrary
static var _skin_shader: Shader
static var _cloth_shader: Shader


## colors: Skin, Shirt, Pants, Socks (shoes), Hair. `hair` picks a style by
## index; -1 leaves the head shaved. `bulk` is muscle: 0 is a lean college
## build, 1 is the bodybuilder the mesh was sculpted as.
static func build(colors: Dictionary, hair: int = 0, bulk: float = 0.0) -> Node3D:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.name = "Model"
	var skin: ShaderMaterial = ShaderMaterial.new()
	skin.shader = _get_skin_shader()
	skin.set_shader_parameter("skin_tex", load("res://assets/court/player_T_Superhero_Male_Dark.png"))
	skin.set_shader_parameter("skin_tint", colors.get("Skin", Color(0.48, 0.34, 0.24)))
	skin.set_shader_parameter("shoes", colors.get("Socks", Color.WHITE))
	skin.set_shader_parameter("definition", 0.3 + 0.7 * clampf(bulk, 0.0, 1.0))
	var style: int = hair % HAIR_STYLES.size() if hair >= 0 else -1
	skin.set_shader_parameter("hair_mask", Vector2(1.0 if style == 0 else 0.0, 1.0 if style == 1 else 0.0))
	skin.set_shader_parameter("hair_color", colors.get("Hair", Color(0.08, 0.07, 0.06)))
	var cloth: ShaderMaterial = ShaderMaterial.new()
	cloth.shader = _get_cloth_shader()
	cloth.set_shader_parameter("jersey", colors.get("Shirt", Color.WHITE))
	cloth.set_shader_parameter("shorts", colors.get("Pants", Color.WHITE))
	var hair_mat: StandardMaterial3D = StandardMaterial3D.new()
	hair_mat.albedo_color = colors.get("Hair", Color(0.08, 0.07, 0.06))
	hair_mat.roughness = 0.9
	var wanted: String = HAIR_STYLES[hair % HAIR_STYLES.size()] if hair >= 0 else ""
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh_name: String = str(mi.name)
		var shape: int = mi.find_blend_shape_by_name("Bulk")
		if shape >= 0:
			mi.set_blend_shape_value(shape, clampf(bulk, 0.0, 1.0))
		if mesh_name == "SuperHero_Male":
			mi.material_override = skin
		elif mesh_name == "Uniform":
			mi.material_override = cloth
		elif mesh_name.begins_with("Hair_"):
			mi.visible = mesh_name == wanted
			mi.material_override = hair_mat
		elif mesh_name == "Eyebrows":
			mi.material_override = hair_mat
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.add_animation_library("", library())
	return model


static func build_student(colors: Dictionary) -> Node3D:
	var model: Node3D = (load(STUDENT) as PackedScene).instantiate()
	model.name = "Model"
	# The game scales the root for a player's height, so the rig's own size
	# (it imports ~4.8 m tall) is applied one level down.
	(model.get_node("HumanArmature") as Node3D).scale *= CharacterAppearance.CHARACTER_SCALE
	var wanted: Dictionary = {"Skin": colors.get("Skin", Color(0.48, 0.34, 0.24)),
		"Hair": colors.get("Hair", Color(0.08, 0.07, 0.06)), "Shirt": colors.get("Shirt", Color.WHITE),
		"Pants": colors.get("Pants", Color.WHITE), "Socks": colors.get("Socks", Color.WHITE)}
	var mi: MeshInstance3D = CharacterAppearance.find_mesh(model)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _crotch_reweighted(mi.mesh, mi.skin)
	for i in mi.mesh.get_surface_count():
		var base: Material = mi.mesh.surface_get_material(i)
		if base != null and wanted.has(base.resource_name):
			var mat: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
			mat.albedo_color = wanted[base.resource_name]
			mi.set_surface_override_material(i, mat)
	var player: AnimationPlayer = model.get_node("AnimationPlayer")
	for lib: StringName in player.get_animation_library_list():
		player.remove_animation_library(lib)
	player.add_animation_library("", library())
	return model


## The student's shorts have a seam of vertices along the crotch and back panel, at the lowest edge
## of the shorts, that the source weights almost wholly to the hips, while the vertices around them
## follow the thighs. The defensive slide throws the legs far apart, the seam stays on the pelvis, and
## the triangles between it and the thigh vertices stretch into spikes (a jagged skirt hanging behind
## the player). Here that seam follows the nearer thigh: SEAM_TO_THIGH of its hip weight moves to the
## upper leg whose joint is closer to the vertex, shared between both when it is central.
const SEAM_TO_THIGH: float = 0.65
const SEAM_BAND: float = 0.3  # lowest fraction of the shorts' height that counts as the seam
static var _reweighted: Dictionary = {}

static func _crotch_reweighted(mesh: ArrayMesh, skin: Skin) -> ArrayMesh:
	var key: int = mesh.get_instance_id()
	if _reweighted.has(key):
		return _reweighted[key]
	var names: Array = []
	for i in skin.get_bind_count():
		names.append(str(skin.get_bind_name(i)))
	var hips: int = names.find("Hips")
	var left: int = names.find("LeftUpperLeg")
	var right: int = names.find("RightUpperLeg")
	if hips < 0 or left < 0 or right < 0:
		return mesh
	var out: ArrayMesh = ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var mat: Material = mesh.surface_get_material(s)
		var fmt: int = mesh.surface_get_format(s)
		if mat != null and mat.resource_name == "Pants":
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per: int = bones.size() / verts.size()
			var ymin: float = INF
			var ymax: float = -INF
			for v: Vector3 in verts:
				ymin = minf(ymin, v.y)
				ymax = maxf(ymax, v.y)
			for v in verts.size():
				if verts[v].y > ymin + (ymax - ymin) * SEAM_BAND:
					continue
				var slot_hips: int = -1
				for k in per:
					if bones[v * per + k] == hips and wts[v * per + k] > 0.5:
						slot_hips = k
				if slot_hips < 0:
					continue
				var d_left: float = (skin.get_bind_pose(left) * verts[v]).length()
				var d_right: float = (skin.get_bind_pose(right) * verts[v]).length()
				var share_left: float = 0.5 if absf(d_left - d_right) < 0.1 * minf(d_left, d_right) else (1.0 if d_left < d_right else 0.0)
				var moved: float = wts[v * per + slot_hips] * SEAM_TO_THIGH
				wts[v * per + slot_hips] -= moved
				for pair: Array in [[left, share_left], [right, 1.0 - share_left]]:
					if float(pair[1]) <= 0.0:
						continue
					var slot: int = -1
					for k in per:
						if bones[v * per + k] == int(pair[0]):
							slot = k
					if slot < 0:
						for k in per:
							if wts[v * per + k] <= 0.0 and slot < 0:
								slot = k
						if slot < 0:
							continue
						bones[v * per + slot] = int(pair[0])
					wts[v * per + slot] += moved * float(pair[1])
			arr[Mesh.ARRAY_BONES] = bones
			arr[Mesh.ARRAY_WEIGHTS] = wts
		var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() == 8 * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() else 0
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arr, [], {}, flags)
		out.surface_set_material(s, mat)
		out.surface_set_name(s, mesh.surface_get_name(s))
	_reweighted[key] = out
	return out


static func find_skeleton(model: Node) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	return found[0] if not found.is_empty() else null


## One shared library: every clip, renamed and with its loop mode set.
static func library() -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	var sources: Dictionary = {}
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		var path: String = spec[0]
		if not sources.has(path):
			sources[path] = (load(path) as PackedScene).instantiate()
		var src: AnimationPlayer = (sources[path] as Node).find_children("*", "AnimationPlayer", true, false)[0]
		if not src.has_animation(spec[1]):
			push_warning("court clip missing: %s in %s" % [spec[1], path])
			continue
		var anim: Animation = src.get_animation(spec[1]).duplicate()
		anim.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
		_library.add_animation(clip, anim)
	if students and mocap_retarget:
		_retarget_mocap(sources)
	for scene: Node in sources.values():
		scene.free()
	_ground_clips()
	_calm_shoulders()
	_borrow_run_arms("Jog")
	_neutral_upper("Pass")
	_neutral_upper("Reach")
	_neutral_upper("Clap")
	return _library


## Mocap from another body lands a little high or low after retargeting.
## GROUND_OFFSETS (metres, measured by tests/court_model_view) lifts each
## clip's hips track so the planted foot meets the floor like Idle's does.
## The QA test fails if any clip is more than 2 cm off, so re-measure there
## whenever a clip is rebuilt.
static func _ground_clips() -> void:
	for clip: String in GROUND_OFFSETS:
		if not _library.has_animation(clip):
			continue
		var delta: float = GROUND_OFFSETS[clip]
		var anim: Animation = _library.get_animation(clip)
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(anim.track_get_path(t)).ends_with(":Hips"):
				continue
			for k in anim.track_get_key_count(t):
				var v: Vector3 = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, v + Vector3(0, delta, 0))


## Mocap shoulders arrive shrugged and rolled forward (a different body's
## clavicle rest), which reads as shoulder pads. Each clavicle keeps only
## SHOULDER_KEEP of its motion, measured against where Idle holds it.
const SHOULDER_KEEP: float = 0.3

static func _calm_shoulders() -> void:
	var idle: Animation = _library.get_animation("Idle")
	for clip: String in CLIPS:
		# the retargeted clips carry the CMU clavicles as recorded, without the shrug the import retarget added
		if not CLIPS[clip][3] or not _library.has_animation(clip) or (students and mocap_retarget and clip in RETARGETED):
			continue
		var anim: Animation = _library.get_animation(clip)
		for t in anim.get_track_count():
			var path: String = str(anim.track_get_path(t))
			if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D or not path.to_lower().contains("shoulder"):
				continue
			var ref_track: int = idle.find_track(anim.track_get_path(t), Animation.TYPE_ROTATION_3D)
			if ref_track < 0:
				continue
			var rest: Quaternion = idle.track_get_key_value(ref_track, 0)
			for k in anim.track_get_key_count(t):
				var q: Quaternion = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, rest.slerp(q, SHOULDER_KEEP))


## Rebuilds the RETARGETED clips for the campus student from the CMU files.
static func _retarget_mocap(sources: Dictionary) -> void:
	var student: Node = (load(STUDENT) as PackedScene).instantiate()
	var sk: Skeleton3D = find_skeleton(student)
	for clip: String in RETARGETED:
		if not _library.has_animation(clip):
			continue
		var spec: Array = CLIPS[clip]
		var src: Node = sources[spec[0]]
		var cmu_player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		Retarget.apply(_library.get_animation(clip), find_skeleton(src), cmu_player.get_animation(spec[1]), sk)
	student.free()


static func _get_skin_shader() -> Shader:
	if _skin_shader != null:
		return _skin_shader
	_skin_shader = Shader.new()
	_skin_shader.code = """
shader_type spatial;
uniform sampler2D skin_tex : source_color;
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform vec4 shoes : source_color = vec4(1.0);
uniform vec2 hair_mask = vec2(0.0);
uniform float definition = 0.3;  // how much of the painted muscle shading shows
uniform vec4 hair_color : source_color = vec4(0.08, 0.07, 0.06, 1.0);
void fragment() {
	vec3 skin = texture(skin_tex, UV).rgb;
	// Keep the painted shading, swap the hue.
	float shade = mix(1.0, clamp(dot(skin, vec3(0.333)) * 2.2, 0.35, 1.25), definition);
	vec3 base = mix(skin * mix(1.0, shade, 0.0), skin_tint.rgb * shade, 0.75 + 0.25 * (1.0 - definition));
	base = mix(base, shoes.rgb, step(0.5, COLOR.b));
	// Scalp under the hair takes the hair colour, so nothing bald shows through.
	float scalp = clamp(step(0.5, COLOR.r) * hair_mask.x + step(0.5, COLOR.g) * hair_mask.y, 0.0, 1.0);
	base = mix(base, hair_color.rgb, scalp);
	ALBEDO = base;
	ROUGHNESS = 0.85;
}
"""
	return _skin_shader


static func _get_cloth_shader() -> Shader:
	if _cloth_shader != null:
		return _cloth_shader
	_cloth_shader = Shader.new()
	_cloth_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 jersey : source_color = vec4(1.0);
uniform vec4 shorts : source_color = vec4(1.0);
void fragment() {
	ALBEDO = mix(shorts.rgb, jersey.rgb, step(0.5, COLOR.r));
	ROUGHNESS = 0.95;
}
"""
	return _cloth_shader


## The library's jog holds the forearms level and swings the upper arms
## stiffly behind. The CMU run has a real arm pump, so the jog borrows its
## arm tracks, shifted so each arm swings against the same leg as it does there.
static func _borrow_run_arms(target: String) -> void:
	if not _library.has_animation(target) or not _library.has_animation("Run"):
		return
	var run: Animation = _library.get_animation("Run")
	var dst: Animation = _library.get_animation(target)
	var shift: float = float(CLIP_STRIKE["Run"]) / run.length - float(CLIP_STRIKE[target]) / dst.length
	const STEPS: int = 30
	for t in dst.get_track_count():
		var path: String = str(dst.track_get_path(t))
		if dst.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		if not (path.ends_with("UpperArm") or path.ends_with("LowerArm") or path.ends_with("Hand")):
			continue
		var rt: int = run.find_track(dst.track_get_path(t), Animation.TYPE_ROTATION_3D)
		if rt < 0:
			continue
		for k in range(dst.track_get_key_count(t) - 1, -1, -1):
			dst.track_remove_key(t, k)
		for i in STEPS + 1:
			var u: float = float(i) / STEPS
			dst.rotation_track_insert_key(t, u * dst.length, run.rotation_track_interpolate(rt, fposmod((u + shift) * run.length, run.length)))


## Pass, Reach and Clap are upper-body overlays whose hands the game places
## with IK; the library clips they came from stoop and push. Each becomes a
## short hold of Idle's upright pose, so only the IK moves the arms.
static func _neutral_upper(clip: String) -> void:
	if not _library.has_animation("Idle"):
		return
	var anim: Animation = _library.get_animation("Idle").duplicate()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_NONE
	if _library.has_animation(clip):
		_library.remove_animation(clip)
	_library.add_animation(clip, anim)
