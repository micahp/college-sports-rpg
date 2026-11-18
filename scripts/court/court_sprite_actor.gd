extends "res://scripts/court/court_actor.gd"
## A court player drawn as a sprite. Same steering and the same interface the
## court game uses, but there is no 3D model, rig or mocap anywhere: every
## pose is a frame from the sheets drawn by tools/court_sprites/draw.gd
## (2D shapes placed from hand-written poses, 8 directions).
## The sheets store part and shade, not colour; the shader paints the team
## and player colours, so one set of sheets serves every player.

const SPRITES: String = "res://assets/court/sprites"
const WITH_BALL: Dictionary = {"Idle": "DribIdle", "DribbleRun": "Dribble", "Walk": "Dribble",
	"JogM": "DribJogM", "Run": "DribRun", "Jog": "DribJog"}
## How far in front of his feet the whole sprite is depth-tested (metres), so
## the floor never cuts through his shoes and players sort by where they stand.
const DEPTH_BIAS: float = 0.6

static var _meta: Dictionary = {}
static var _sheets: Dictionary = {}
static var _shader: Shader

var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _clip: String = ""
var _u: float = 0.0  # 0..1 through the clip on screen
var _dir: int = 0
var _disp_yaw: float = 0.0
var _act: String = ""
var _act_t: float = 0.0
var _act_speed: float = 1.0
var _uact: String = ""
var _uact_t: float = 0.0
var _uact_speed: float = 1.0
var _idle_u: float = 0.0
var _drib_phase: float = 0.0
var _drib_prev: float = 0.0


static func meta() -> Dictionary:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPRITES + "/meta.json"))
		_meta = parsed if parsed is Dictionary else {"clips": {}}
	return _meta


static func clip_info(clip: String) -> Dictionary:
	return (meta()["clips"] as Dictionary).get(clip, {})


static func sheet(clip: String) -> Texture2D:
	if not _sheets.has(clip):
		var img: Image = load("%s/%s.res" % [SPRITES, clip]) as Image
		_sheets[clip] = ImageTexture.create_from_image(img) if img != null else null
	return _sheets[clip]


func setup(_model_key: String, colors: Dictionary, _hair: int = 0, _bulk: float = 0.0) -> void:
	_model = Node3D.new()  # holds his facing and height; nothing is drawn under it
	_model.name = "Model"
	add_child(_model)
	add_child(CharacterAppearance.blob_shadow())
	_quad = MeshInstance3D.new()
	_quad.mesh = QuadMesh.new()
	_quad.extra_cull_margin = 5.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = sprite_shader()
	_mat.set_shader_parameter("jersey", colors.get("Shirt", Color.WHITE))
	_mat.set_shader_parameter("shorts", colors.get("Pants", Color.WHITE))
	_mat.set_shader_parameter("skin", colors.get("Skin", Color(0.48, 0.34, 0.24)))
	_mat.set_shader_parameter("hair", colors.get("Hair", Color(0.08, 0.07, 0.06)))
	_mat.set_shader_parameter("shoes", colors.get("Socks", Color.WHITE))
	_mat.set_shader_parameter("depth_bias", DEPTH_BIAS)
	_quad.material_override = _mat
	add_child(_quad)
	_openness_label = Label3D.new()
	_openness_label.text = "OPEN"
	_openness_label.font_size = 40
	_openness_label.outline_size = 10
	_openness_label.modulate = Color(0.92, 0.72, 0.3)
	_openness_label.outline_modulate = Color(0.03, 0.05, 0.1)
	_openness_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_openness_label.no_depth_test = true
	_openness_label.position = Vector3(0, 2.35, 0)
	_openness_label.visible = false
	add_child(_openness_label)
	_show("Idle", 0.0)


func animate(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)
	beaten = maxf(0.0, beaten - delta)
	reach_cd = maxf(0.0, reach_cd - delta)
	_action_time = maxf(0.0, _action_time - delta)
	var s: float = Vector2(vel.x, vel.z).length()
	if face_lock:
		turn_toward(face_target, delta)
	elif s > 0.35 and _action_time <= 0.0:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(vel.x, vel.z), minf(1.0, 12.0 * delta))
	# Gait, and how far through the stride he is (kept across gait switches).
	_switch_wait = maxf(0.0, _switch_wait - delta)
	var gait: String = _pick_gait(s)
	if gait != _gait and (_switch_wait <= 0.0 or _gait == ""):
		_gait = gait
		_switch_wait = 0.22
	var rate: float = 1.0
	var gait_info: Dictionary = clip_info(_gait_clip(_gait))
	if gait_info.has("speed"):
		rate = clampf(s / float(gait_info["speed"]), 0.7, 1.5)
		_stride = fposmod(_stride + delta * rate / _length(_gait_clip(_gait)), 1.0)
	_idle_u = fposmod(_idle_u + delta / _length("DribIdle" if has_ball else "Idle"), 1.0)
	# What to show, most specific first.
	var clip: String = _gait_clip(_gait)
	var u: float = _gait_u(_gait)
	if has_ball and WITH_BALL.has(_gait):
		clip = WITH_BALL[_gait]
	if role == "screen_set" and s < 0.6:
		clip = "Screen"
		u = 0.0
	elif elbow_up and goal_w_r > 0.5 and goal_w_l > 0.5:
		clip = "HandsUp"
		u = 0.0
	elif elbow_up and goal_w_r > 0.5 and s < 0.6:
		clip = "CallBall"
		u = 0.0
	if _uact != "":
		_uact_t += delta * _uact_speed
		if _uact_t >= _length(_uact):
			_uact = ""
		else:
			clip = _uact
			u = _uact_t / _length(_uact)
	if _act != "":
		_act_t += delta * _act_speed
		if _act_t >= _length(_act):
			_act = ""
		else:
			clip = _act
			u = _act_t / _length(_act)
	_show(clip, u)


## With the ball he walks it up to a jog's pace, then the running gaits
## take over (each baked with its own dribble rhythm).
func _pick_gait(s: float) -> String:
	if has_ball and not (face_lock and team == 1) and s >= 0.25:
		if s < (1.9 if _gait == "DribbleRun" else 1.6):
			return "DribbleRun"
		return _run_gait(maxf(s, 2.0))
	return super._pick_gait(s)


func _gait_clip(gait: String) -> String:
	return "Dribble" if gait == "DribbleRun" else gait


func _gait_u(gait: String) -> float:
	if gait == "Idle":
		return _idle_u
	return _stride  # every drawn stride starts with the left foot landing


func _length(clip: String) -> float:
	return maxf(0.05, float(clip_info(clip).get("length", 1.0)))


## Puts one frame on screen: the clip, how far through it, and the direction
## he is seen from (his facing against the line from the camera).
func _show(clip: String, u: float) -> void:
	var info: Dictionary = clip_info(clip)
	if info.is_empty():
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var to_cam: float = 0.0
	if cam != null:
		to_cam = atan2(cam.global_position.x - global_position.x, cam.global_position.z - global_position.z)
	var step: float = TAU / 8.0
	var rel: float = wrapf(_model.rotation.y - to_cam, 0.0, TAU)
	# Stay on the current direction until he has clearly turned past it.
	if absf(angle_difference(rel, _dir * step)) > step * 0.62:
		_dir = posmod(roundi(rel / step), 8)
	_disp_yaw = to_cam + _dir * step
	var frames: int = int(info["frames"])
	var frame: int = clampi(int(u * frames), 0, frames - 1)
	if clip != _clip:
		_clip = clip
		_mat.set_shader_parameter("sheet", sheet(clip))
		_mat.set_shader_parameter("cell", Vector2(float(info["cw"]), float(info["ch"])))
		_mat.set_shader_parameter("anchor", Vector2(float(info["ax"]), float(info["ay"])))
	_u = u
	_mat.set_shader_parameter("frame", Vector2(frame, _dir))
	_mat.set_shader_parameter("px_size", _model.scale.x / float(meta().get("px_per_m", 57.46)))


func action(anim_name: String, speed: float = 1.0, start: float = 0.0) -> void:
	if clip_info(anim_name).is_empty():
		return
	if anim_name in UPPER_ACTIONS:
		_uact = anim_name
		_uact_t = 0.0
		_uact_speed = speed
		return
	var length: float = _length(anim_name)
	start = clampf(start, 0.0, length - 0.1)
	_act = anim_name
	_act_t = start
	_act_speed = speed
	_action_time = (length - start) / speed


## Where the hand is in the frame on screen (recorded when the frame was baked).
func hand_position(side: String) -> Vector3:
	var pts: Array = clip_info(_clip).get("hand_r" if side == "R" else "hand_l", [])
	if pts.is_empty():
		return position + Vector3(0, 1.2, 0)
	var n: int = pts.size()
	var x: float = clampf(_u, 0.0, 0.9999) * n
	var i: int = int(x)
	var a: Array = pts[i]
	var b: Array = pts[(i + 1) % n] if bool(clip_info(_clip).get("loop", false)) else pts[mini(i + 1, n - 1)]
	var local: Vector3 = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), x - i)
	return global_position + Basis(Vector3.UP, _disp_yaw) * (local * _model.scale.x)


## The ball while he dribbles: the same curve the dribbling hand was baked
## on (CourtDribble), so it leaves the hand, bounces and comes back to it.
func dribble_ball(_delta: float, floor_y: float) -> Vector3:
	ball_hit_floor = false
	var info: Dictionary = clip_info(_clip)
	if not info.has("ball"):
		_drib_prev = 0.0
		return hand_position("R") - Vector3(0, CourtDribble.RADIUS, 0)
	var phase: float = fposmod(_u * float(info["dribbles"]), 1.0)
	var bounce: float = float(info["bounce"])
	if _drib_prev < bounce and phase >= bounce:
		ball_hit_floor = true
	_drib_prev = phase
	var k: float = _model.scale.x
	var y: float = CourtDribble.sample(info["ball"], phase)
	var local: Vector3 = Vector3(CourtDribble.LOCAL.x * k, 0.0, CourtDribble.LOCAL.z * k)
	var p: Vector3 = global_position + Basis(Vector3.UP, _disp_yaw) * local
	p.y = floor_y - CourtDribble.RADIUS + maxf(CourtDribble.RADIUS, y * k)
	return p


static func sprite_shader() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
// R = shade, G = part code (0 clear, 1 outline, 2 jersey, 3 shorts, 4 hair, 5 skin, 6 shoes).
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec2 cell = vec2(64.0, 100.0);
uniform vec2 anchor = vec2(32.0, 90.0);
uniform vec2 frame = vec2(0.0);
uniform float px_size = 0.0174;
uniform float depth_bias = 0.6;
uniform vec4 jersey : source_color = vec4(1.0);
uniform vec4 shorts : source_color = vec4(1.0);
uniform vec4 skin : source_color = vec4(0.48, 0.34, 0.24, 1.0);
uniform vec4 hair : source_color = vec4(0.08, 0.07, 0.06, 1.0);
uniform vec4 shoes : source_color = vec4(1.0);
uniform vec4 outline : source_color = vec4(0.05, 0.045, 0.08, 1.0);
varying vec2 cuv;

void vertex() {
	cuv = UV * cell;
	// Upright on screen, feet on the player's spot.
	vec3 o = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	vec3 v = o + vec3((cuv.x - anchor.x) * px_size, (anchor.y - cuv.y) * px_size, 0.0);
	vec4 clip = PROJECTION_MATRIX * vec4(v, 1.0);
	// One depth for the whole sprite, a little in front of his feet.
	vec4 d = PROJECTION_MATRIX * vec4(o + vec3(0.0, 0.0, depth_bias), 1.0);
	clip.z = d.z / d.w * clip.w;
	POSITION = clip;
}

vec4 texel(vec2 p) {
	if (p.x < 0.0 || p.y < 0.0 || p.x >= cell.x || p.y >= cell.y) {
		return vec4(0.0);
	}
	vec2 rg = texelFetch(sheet, ivec2(frame * cell + p), 0).rg;
	int code = int(rg.g * 255.0 / 28.0 + 0.5);
	if (code == 0) {
		return vec4(0.0);
	}
	if (code == 1) {
		return vec4(outline.rgb, 1.0);
	}
	float s = pow(rg.r, 2.2);
	vec3 c = vec3(0.85);
	if (code == 2) { c = jersey.rgb; }
	else if (code == 3) { c = shorts.rgb; }
	else if (code == 4) { c = hair.rgb; }
	else if (code == 5) { c = skin.rgb; }
	else if (code == 6) { c = shoes.rgb; }
	return vec4(c * s, 1.0);
}

void fragment() {
	// Crisp pixels that don't shimmer when the sprite isn't at a whole-number
	// scale: blend only across the last screen pixel of each texel edge.
	vec2 p = cuv - 0.5;
	vec2 base = floor(p);
	vec2 f = clamp((p - base - 0.5) / max(fwidth(cuv), vec2(0.0001)) + 0.5, 0.0, 1.0);
	vec4 a = texel(base);
	vec4 b = texel(base + vec2(1.0, 0.0));
	vec4 c = texel(base + vec2(0.0, 1.0));
	vec4 d = texel(base + vec2(1.0, 1.0));
	vec4 col = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	if (col.a < 0.5) {
		discard;
	}
	ALBEDO = col.rgb / col.a;
}
"""
	return _shader


## The ball as a sprite: a pixel basketball that always faces the camera and
## draws over a player unless it is clearly behind him.
static func ball_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float px_size = 0.0174;
uniform float depth_bias = 0.85;
varying vec2 cuv;
void vertex() {
	cuv = UV * 16.0;
	vec3 o = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	vec3 v = o + vec3((cuv.x - 8.0) * px_size, (8.0 - cuv.y) * px_size, 0.0);
	vec4 clip = PROJECTION_MATRIX * vec4(v, 1.0);
	vec4 d = PROJECTION_MATRIX * vec4(o + vec3(0.0, 0.0, depth_bias), 1.0);
	clip.z = d.z / d.w * clip.w;
	POSITION = clip;
}
vec4 texel(vec2 p) {
	vec2 q = p + 0.5 - 8.0;
	float r = length(q);
	if (r > 8.0) { return vec4(0.0); }
	if (r > 6.9) { return vec4(0.05, 0.045, 0.08, 1.0); }
	vec3 c = vec3(0.86, 0.40, 0.12);
	if (q.x + q.y > 4.0) { c *= 0.62; }
	else if (q.x + q.y > 0.5) { c *= 0.82; }
	if (abs(q.x + 0.5) < 0.6 || abs(q.y - q.x * q.x * 0.06 + 0.5) < 0.6) { c = vec3(0.16, 0.08, 0.05); }
	if (length(q + vec2(2.5, 2.5)) < 1.3) { c = vec3(1.0, 0.62, 0.32); }
	return vec4(c, 1.0);
}
void fragment() {
	vec2 p = cuv - 0.5;
	vec2 base = floor(p);
	vec2 f = clamp((p - base - 0.5) / max(fwidth(cuv), vec2(0.0001)) + 0.5, 0.0, 1.0);
	vec4 col = mix(mix(texel(base), texel(base + vec2(1.0, 0.0)), f.x),
		mix(texel(base + vec2(0.0, 1.0)), texel(base + vec2(1.0, 1.0)), f.x), f.y);
	if (col.a < 0.5) { discard; }
	ALBEDO = pow(col.rgb / col.a, vec3(2.2));
}
"""
	m.set_shader_parameter("px_size", 1.0 / float(meta().get("px_per_m", 57.46)))
	return m
