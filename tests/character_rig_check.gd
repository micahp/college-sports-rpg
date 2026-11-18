extends Node
## Scale-free limb proportions of every game character, against the football body
## (web/stack/skeleton.js). Each segment is divided by the hips-to-head joint
## distance, so units and import scale drop out.
# Football body, metres: hips joint -> head joint = 0.10 + 0.20 + 0.31 + 0.09 = 0.70.
const REF := {"thigh": 0.45 / 0.70, "shin": 0.43 / 0.70, "upper_arm": 0.29 / 0.70, "forearm": 0.26 / 0.70}
const ALIASES := {
	"UpperLeg.L": ["LeftUpperLeg", "UpperLeg.L"], "LowerLeg.L": ["LeftLowerLeg", "LowerLeg.L"], "Foot.L": ["LeftFoot", "LowerLeg.L_end"],
	"UpperArm.L": ["LeftUpperArm", "UpperArm.L"], "LowerArm.L": ["LeftLowerArm", "LowerArm.L"], "Hand.L": ["LeftHand", "Palm.L"],
}

func _ready() -> void:
	var files: Array = []
	var d := DirAccess.open("res://assets/characters")
	for f in d.get_files():
		if f.ends_with(".fbx"):
			files.append("res://assets/characters/" + f)
	files.append("res://assets/court/students/Male_Casual.fbx")
	for f in files:
		_measure(f)
	print("REF    thigh %.3f  shin %.3f  upper_arm %.3f  forearm %.3f  (share of hips-to-head)" % [REF["thigh"], REF["shin"], REF["upper_arm"], REF["forearm"]])
	get_tree().quit(0)

func _bone(sk: Skeleton3D, key: String) -> int:
	for n in ALIASES.get(key, [key]):
		var i := sk.find_bone(n)
		if i >= 0: return i
	return -1

func _measure(path: String) -> void:
	var root: Node = load(path).instantiate()
	add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var hips := _bone(sk, "Hips") if _bone(sk, "Hips") >= 0 else sk.find_bone("Hips")
	var head := sk.find_bone("Head")
	var torso_len: float = (sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hips).origin).length() if hips >= 0 and head >= 0 else -1.0
	var seg := func(a_key: String, b_key: String) -> float:
		var a := _bone(sk, a_key)
		var b := _bone(sk, b_key)
		if a < 0 or b < 0 or torso_len <= 0.0: return -1.0
		return (sk.get_bone_global_rest(b).origin - sk.get_bone_global_rest(a).origin).length() / torso_len
	var thigh: float = seg.call("UpperLeg.L", "LowerLeg.L")
	var shin: float = seg.call("LowerLeg.L", "Foot.L")
	var upper: float = seg.call("UpperArm.L", "LowerArm.L")
	var fore: float = seg.call("LowerArm.L", "Hand.L")
	print("CHAR %-24s thigh %.3f (%+.0f%%)  shin %.3f (%+.0f%%)  upper_arm %.3f (%+.0f%%)  forearm %.3f (%+.0f%%)  shin/thigh %.2f  forearm/upper %.2f" % [
		path.get_file(), thigh, _pct(thigh, REF["thigh"]), shin, _pct(shin, REF["shin"]), upper, _pct(upper, REF["upper_arm"]),
		fore, _pct(fore, REF["forearm"]), shin / thigh, fore / upper])
	root.queue_free()

func _pct(v: float, r: float) -> float:
	return (v / r - 1.0) * 100.0 if v > 0.0 else NAN
