extends Node
## Runs rig certification gates 1-5 headless (each its own Godot process, as
## a person would), then each gate again with every fault it is meant to
## catch, and prints the gate report. A fault counts as caught only if it
## makes a check fail that passes without it: a gate that is already failing
## cannot hide an injected defect behind its own failures.
##   godot --headless --path . res://tests/rig/certify.tscn
## Exit 0 only if every gate passes and every fault is caught.
const GATES: Array = [
	["1 skeleton integrity", "res://tests/rig/skeleton_checks.tscn", ["bone_offset", "axis_roll", "pole_axis"]],
	["2 skin deformation", "res://tests/rig/skin_deformation_checks.tscn", ["bad_weight"]],
	["3 limb IK in isolation", "res://tests/rig/arm_ik_sweep.tscn", ["pole_plus_z", "hinge_on"]],
	["4 poles and limits", "res://tests/rig/pole_rotation_checks.tscn", ["world_pole"]],
	["5 corrections in isolation", "res://tests/rig/correction_isolation.tscn", ["rogue"]],
]


func _run(scene: String, fault: String) -> Dictionary:
	var args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), scene])
	if fault != "":
		args.append_array(["--", "fault=" + fault])
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var failed: Array = []
	var summary := ""
	for line: String in "\n".join(out).split("\n"):
		if line.begins_with("FAILED_CHECKS: "):
			for c: String in line.substr(15).split(","):
				if c != "":
					failed.append(c)
		elif line.begins_with("GATE ") and line.contains(" checks, "):
			summary = line
	return {"code": code, "failed": failed, "summary": summary}


func _ready() -> void:
	var all_ok := true
	var report: Array = []
	for g: Array in GATES:
		var base := _run(g[1], "")
		var passed: bool = int(base["code"]) == 0
		all_ok = all_ok and passed
		report.append("GATE %s: %s  (%s)" % [g[0], "PASS" if passed else "FAIL", base["summary"]])
		for c: String in base["failed"]:
			report.append("    failing: " + c)
		for fault: String in g[2]:
			var r := _run(g[1], fault)
			var new_fails: Array = (r["failed"] as Array).filter(func(c): return not (c in base["failed"]))
			var caught := not new_fails.is_empty()
			all_ok = all_ok and caught
			report.append("    fault %-12s %s%s" % [fault, "caught by: " if caught else "NOT CAUGHT", ", ".join(new_fails)])
	print("\nRIG CERTIFICATION REPORT (campus student rig)")
	for l: String in report:
		print(l)
	print("CERTIFIED" if all_ok else "NOT CERTIFIED")
	get_tree().quit(0 if all_ok else 1)
