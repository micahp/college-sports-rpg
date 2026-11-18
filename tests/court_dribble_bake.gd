extends Node3D
## Bakes the ball's flight for the dribble mocap into assets/court/dribble_ball.json.
##
## The dribble clip was recorded with a real basketball, so the hand pumps at
## a real rhythm. This samples that hand over the loop, finds where it
## releases the ball (bottom of the push) and where it meets it again (top),
## and solves the flight between them as projectile motion: constant speed
## across the floor, gravity in the air, one bounce that keeps E of its speed.
## The game then places the ball from this table: in the hand during the
## push, on the solved flight in between.
##
##   godot --headless tests/court_dribble_bake.tscn

const CLIP: String = "DribbleRun"
const SAMPLES: int = 120
const R: float = 0.12
const G: float = 9.81
const E: float = 0.78


func _ready() -> void:
	var model: Node3D = CourtPlayerModel.build({})
	add_child(model)
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(model)
	var ap: AnimationPlayer = model.get_node("AnimationPlayer")
	var length: float = ap.get_animation(CLIP).length
	ap.play(CLIP)
	var hands: Dictionary = {"R": [], "L": []}
	for i in SAMPLES:
		ap.seek(length * i / SAMPLES, true)
		sk.force_update_all_bone_transforms()
		for side: String in ["R", "L"]:
			var bone: String = "RightHand" if side == "R" else "LeftHand"
			# model space: +Z is the way he faces
			var p: Vector3 = model.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin)
			(hands[side] as Array).append(p)
	var side: String = "R" if _travel(hands["R"]) >= _travel(hands["L"]) else "L"
	var hand: Array = hands[side]
	var ys: Array[float] = []
	for i in SAMPLES:  # smooth over 5 samples, cyclic
		var acc: float = 0.0
		for k in range(-2, 3):
			acc += (hand[posmod(i + k, SAMPLES)] as Vector3).y
		ys.append(acc / 5.0)
	var lo: float = ys.min()
	var hi: float = ys.max()
	print("DRIBBLE hand %s: height %.2f..%.2f m over a %.2fs loop" % [side, lo, hi, length])
	# Turning points (cyclic): tops and bottoms that stand out by 4 cm.
	var turns: Array = []
	for i in SAMPLES:
		var a: float = ys[posmod(i - 1, SAMPLES)]
		var b: float = ys[i]
		var c: float = ys[posmod(i + 1, SAMPLES)]
		var window_min: float = INF
		var window_max: float = -INF
		for k in range(-14, 15):
			window_min = minf(window_min, ys[posmod(i + k, SAMPLES)])
			window_max = maxf(window_max, ys[posmod(i + k, SAMPLES)])
		var kind: String = ""
		if b >= a and b > c and b - window_min > 0.04 and b >= window_max - 0.001:
			kind = "top"
		elif b <= a and b < c and window_max - b > 0.04 and b <= window_min + 0.001:
			kind = "bottom"
		if kind != "" and (turns.is_empty() or (turns[-1] as Array)[1] != kind):
			turns.append([i, kind])
	if turns.size() >= 2 and (turns[0] as Array)[1] == (turns[-1] as Array)[1]:
		turns.pop_back()
	print("DRIBBLE turning points ", turns)
	var flights: Array = []
	for k in turns.size():
		var cur: Array = turns[k]
		var nxt: Array = turns[(k + 1) % turns.size()]
		if cur[1] != "bottom" or nxt[1] != "top":
			continue
		var t0: float = length * int(cur[0]) / SAMPLES
		var span: float = length * posmod(int(nxt[0]) - int(cur[0]), SAMPLES) / SAMPLES
		var p0: Vector3 = hand[int(cur[0])]
		var p1: Vector3 = hand[int(nxt[0])]
		var fit: Array = _solve(p0.y - R, p1.y - R, span)
		if fit.is_empty():
			print("DRIBBLE release at %.2fs: no physical bounce fits %.2fs (%.2f -> %.2f m)" % [t0, span, p0.y, p1.y])
			continue
		print("DRIBBLE release at %.2fs from %.2f m, floor after %.2fs, back in the hand at %.2f m after %.2fs, pushed down at %.1f m/s" % [
			t0, p0.y, fit[0], p1.y, span, fit[1]])
		flights.append({"t0": t0, "span": span, "tb": fit[0], "v0": fit[1],
			"p0": [p0.x, p0.y - R, p0.z], "p1": [p1.x, p1.y - R, p1.z]})
	var out: Dictionary = {"clip": CLIP, "length": length, "side": side, "radius": R, "gravity": G, "bounce": E,
		"flights": flights}
	var f: FileAccess = FileAccess.open("res://assets/court/dribble_ball.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	var in_air: float = 0.0
	for fl: Dictionary in flights:
		in_air += float(fl["span"])
	print("DRIBBLE BAKED: %d dribble(s) per loop, ball in the air %.0f%% of the time" % [flights.size(), 100.0 * in_air / length])
	get_tree().quit(0 if not flights.is_empty() else 1)


func _travel(points: Array) -> float:
	var total: float = 0.0
	for i in points.size():
		total += absf((points[i] as Vector3).y - (points[posmod(i - 1, points.size())] as Vector3).y)
	return total


## Time to the floor and downward launch speed so the ball leaves at height
## y0, bounces once and is at y1 again after `span` seconds.
func _solve(y0: float, y1: float, span: float) -> Array:
	if span < 0.15 or span > 0.9:
		return []
	var prev_err: float = 0.0
	var have_prev: bool = false
	for k in range(1, 600):
		var tb: float = span * k / 600.0
		var v0: float = (y0 - R - 0.5 * G * tb * tb) / tb
		if v0 < 0.0:
			continue
		var up: float = span - tb
		var err: float = R + E * (v0 + G * tb) * up - 0.5 * G * up * up - y1
		if have_prev and (err > 0.0) != (prev_err > 0.0):
			return [tb, v0]
		prev_err = err
		have_prev = true
	return []
