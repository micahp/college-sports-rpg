@tool
extends EditorScenePostImport
## Import script for the game's character FBX files. Fits the body's proportions
## to the football body (web/stack/skeleton.js). It keeps the file's own legs
## plus torso length and only redistributes it, so campus characters keep their
## height. The court scales its player to 1.81 m at setup (court_actor.gd).
##
## Football body, metres: thigh 0.45, shin 0.43, hips-to-head 0.70, upper arm
## 0.29, forearm 0.26. Legs + torso = 1.58 m. The file's own legs + torso give
## k = M0 / 1.58, and each target is scaled by k, so the total is unchanged.
##
## Scaling a child's rest offset scales its whole chain below it, so the bones
## below move with their segment. Animation rotations are unchanged.

const FOOTBALL: Dictionary = {"thigh": 0.45, "shin": 0.43, "torso": 0.70, "upper_arm": 0.29, "forearm": 0.26}
const LEG_TORSO: float = 0.45 + 0.43 + 0.70
## [segment, parent aliases, child aliases] per side. On the campus rigs the
## ankle is the LowerLeg end bone; Foot.L is a separate root-level IK target.
const SEGMENTS: Array = [
	["thigh", ["LeftUpperLeg", "UpperLeg.L"], ["LeftLowerLeg", "LowerLeg.L"]],
	["shin", ["LeftLowerLeg", "LowerLeg.L"], ["LeftFoot", "LowerLeg.L_end"]],
	["thigh", ["RightUpperLeg", "UpperLeg.R"], ["RightLowerLeg", "LowerLeg.R"]],
	["shin", ["RightLowerLeg", "LowerLeg.R"], ["RightFoot", "LowerLeg.R_end"]],
	["upper_arm", ["LeftUpperArm", "UpperArm.L"], ["LeftLowerArm", "LowerArm.L"]],
	["forearm", ["LeftLowerArm", "LowerArm.L"], ["LeftHand", "Palm.L"]],
	["upper_arm", ["RightUpperArm", "UpperArm.R"], ["RightLowerArm", "LowerArm.R"]],
	["forearm", ["RightLowerArm", "LowerArm.R"], ["RightHand", "Palm.R"]],
]


func _post_import(scene: Node) -> Object:
	var sk: Skeleton3D = _find_skeleton(scene)
	if sk == null:
		return scene
	var hips: int = _first(sk, ["Hips"])
	var head: int = _first(sk, ["Head"])
	if hips < 0 or head < 0:
		push_warning("character_rig_fit: no Hips/Head bone, rig left unchanged")
		return scene
	var thigh0: float = _segment(sk, ["LeftUpperLeg", "UpperLeg.L"], ["LeftLowerLeg", "LowerLeg.L"])
	var shin0: float = _segment(sk, ["LeftLowerLeg", "LowerLeg.L"], ["LeftFoot", "LowerLeg.L_end"])
	var torso0: float = (sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hips).origin).length()
	if thigh0 <= 0.0 or shin0 <= 0.0 or torso0 <= 0.0:
		push_warning("character_rig_fit: could not measure the legs, rig left unchanged")
		return scene
	var k: float = (thigh0 + shin0 + torso0) / LEG_TORSO
	# Torso: every bone from Hips up to Head scales together, so the hips-to-head
	# distance scales exactly.
	var b: int = head
	while b >= 0 and b != hips:
		var r: Transform3D = sk.get_bone_rest(b)
		r.origin *= float(FOOTBALL["torso"]) * k / torso0
		sk.set_bone_rest(b, r)
		b = sk.get_bone_parent(b)
	for seg: Array in SEGMENTS:
		var a: int = _first(sk, seg[1])
		var c: int = _first(sk, seg[2])
		if a < 0 or c < 0:
			continue
		var measured: float = (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(a).origin).length()
		if measured <= 0.0:
			continue
		var rest: Transform3D = sk.get_bone_rest(c)
		rest.origin *= float(FOOTBALL[seg[0]]) * k / measured
		sk.set_bone_rest(c, rest)
	return scene


func _segment(sk: Skeleton3D, parent: Array, child: Array) -> float:
	var a: int = _first(sk, parent)
	var c: int = _first(sk, child)
	if a < 0 or c < 0:
		return -1.0
	return (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(a).origin).length()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


func _first(sk: Skeleton3D, names: Array) -> int:
	for n in names:
		var i := sk.find_bone(n)
		if i >= 0:
			return i
	return -1
