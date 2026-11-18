extends SkeletonModifier3D
## Last modifier on the skeleton: hands the final pose (after IK and foot
## correction, the pose that is actually drawn) to a QA script.

var qa: Node


func _process_modification_with_delta(_delta: float) -> void:
	if qa != null:
		qa.final_pose(get_skeleton())
