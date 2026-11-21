@tool
extends EditorScenePostImport
## Post-import fixes to the campus student rig (Male_Casual.fbx), applied after
## the bone map, so every user of the imported scene gets the same skeleton.
##
## Left arm joints: the mesh is symmetric to 0.00 cm, but the original rig puts
## the left elbow 2.8 cm, wrist 2.5 cm, palm 2.0 cm and finger base 1.3 cm
## further out along the arm than the mirror of the right (the fingertip and
## thumb joints agree), so the left elbow bent 3.9 cm from where its skin bends
## (the right: 1.1 cm). They move to the mirror of the right; the skin is
## rebound so the rest mesh is unchanged (docs/animation/JOINT_ALIGNMENT.md).
## The left hand was also skinned differently from the right (45 of 61 hand,
## 32 of 40 palm and all 20 finger vertices weighted unlike their mirror
## image), around its own shifted pivots: it takes the right hand's weights,
## mirrored, so the whole left arm is the right arm's mirror.
##
## Left leg: the shin and shoe were skinned unlike the right too (16 of 84
## shin and 14 of 62 shoe vertices), and deformed worse (an ankle lifted 30
## deg stretched the left shin 3.5x, the right 1.1x); its joints sat 0.6 cm off
## the right's mirror. It becomes the right leg's mirror the same way.

const Joints = preload("res://scripts/court/rig_joints.gd")
const LEFT_HAND_REGIONS: Array = ["LeftLowerArm", "LeftHand", "MiddleHand.L", "Fingers.L", "Thumb1.L", "Thumb2.L"]
const LEFT_LEG_REGIONS: Array = ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Foot.L"]
## Nine waist vertices on the left were weighted up to 0.38 off their twins.
const LEFT_WAIST_REGIONS: Array = ["Hips", "Spine"]
## Every left arm joint takes the mirror of the right's (the clavicle and
## shoulder were 0.6 cm out, the thumb and fingertips already agreed).
const LEFT_FROM_RIGHT: Dictionary = {
	"LeftShoulder": "RightShoulder", "LeftUpperArm": "RightUpperArm",
	"LeftLowerArm": "RightLowerArm", "LeftHand": "RightHand",
	"MiddleHand.L": "MiddleHand.R", "Fingers.L": "Fingers.R", "Fingers.L_end": "Fingers.R_end",
	"Thumb1.L": "Thumb1.R", "Thumb2.L": "Thumb2.R", "Thumb2.L_end": "Thumb2.R_end",
	"LeftUpperLeg": "RightUpperLeg", "LeftLowerLeg": "RightLowerLeg", "LeftFoot": "RightFoot",
	"Foot.L": "Foot.R", "Foot.L_end": "Foot.R_end",
}


func _post_import(scene: Node) -> Object:
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var moves: Dictionary = {}
	for left: String in LEFT_FROM_RIGHT:
		moves[left] = Joints.mirrored(sk, LEFT_FROM_RIGHT[left])
	var skins: Array = []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and not skins.has(mi.skin):
			skins.append(mi.skin)
			var r: Array = Joints.mirror_weights(sk, mi, LEFT_HAND_REGIONS)
			print("student_rig_fix: left hand weights mirrored from the right on %d vertices (%d without a twin)" % r)
			r = Joints.mirror_weights(sk, mi, LEFT_LEG_REGIONS)
			print("student_rig_fix: left leg weights mirrored from the right on %d vertices (%d without a twin)" % r)
			r = Joints.mirror_weights(sk, mi, LEFT_WAIST_REGIONS)
			print("student_rig_fix: left waist weights mirrored from the right on %d vertices (%d without a twin)" % r)
	Joints.move(sk, moves, skins)
	return scene
