extends Node

const COURT = preload("res://scenes/court/court_game.tscn")
const FootFloor = preload("res://scripts/court/foot_floor.gd")
const CourtPlayerModel = preload("res://scripts/court/court_player_model.gd")
const MOVES = ["Guard stance", "Shuffle and reverse", "Close out", "Retreat", "Diagonal recovery", "Contest", "Swipe"]
const DEFENSE_TAKES := {
	24: "Right, stop to stop", 25: "Left, stop to stop", 27: "Side to side A", 28: "Side to side B",
	22: "Straight, continuous", 23: "Straight with stop", 26: "Zigzag", 29: "Pivot"
}
var court = COURT.instantiate()
var defender
var camera := Camera3D.new()
var menu := OptionButton.new()
var readout := Label.new()
var elapsed := 0.0
var yaw := 0.6
var distance := 2.8
var raw := false
var selection := ""
var max_step := 0.0
var previous := {}
var audit := false
var failures := 0
var show_student := true
var foot_probe: SkeletonModifier3D

func _ready() -> void:
	add_child(court)
	court.set_physics_process(false)
	court._layer.hide()
	defender = _create_defender(true)
	for actor in court._all:
		actor.visible = actor == defender
	court._ball.hide()
	court._target_ring.hide()
	court._user_ring.hide()
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var controls := VBoxContainer.new()
	layer.add_child(controls)
	controls.position = Vector2(12,12)
	controls.add_child(menu)
	var model_toggle := CheckButton.new()
	model_toggle.text = "Campus student model"
	model_toggle.button_pressed = true
	model_toggle.toggled.connect(_set_model)
	controls.add_child(model_toggle)
	for move in MOVES:
		menu.add_item(move)
	for clip in defender._anim.get_animation_list():
		menu.add_item(("CMU / " if clip in ["SlideL","SlideR","Backpedal","DribbleRun","JogM","Run","JumpShot","Layup"] else "Library / ") + clip)
	for take: int in DEFENSE_TAKES:
		menu.add_item("CMU / 102_%d  %s" % [take, DEFENSE_TAKES[take]])
	menu.item_selected.connect(select_move)
	var speed := OptionButton.new()
	for label in ["Normal speed","Half speed","Quarter speed"]:
		speed.add_item(label)
	speed.item_selected.connect(func(i): Engine.time_scale = [1.0,0.5,0.25][i])
	controls.add_child(speed)
	controls.add_child(readout)
	audit = "audit" in OS.get_cmdline_user_args()
	select_move(0 if audit else menu.item_count - DEFENSE_TAKES.size())

func select_move(i: int) -> void:
	menu.select(i)
	selection = menu.get_item_text(i)
	raw = i >= MOVES.size()
	elapsed = 0.0
	max_step = 0.0
	previous.clear()
	court._reach.clear()
	defender.position = Vector3.ZERO
	defender.stop()
	court._user.position = Vector3(0,0,1.35)
	defender.face_point(court._user.position)
	defender.pose_reset()
	defender._tree.active = not raw
	for modifier in defender._skeleton.get_children():
		if modifier is SkeletonModifier3D and modifier.get_script() != preload("res://scripts/court/student_feet.gd"):
			if not modifier.has_meta("lab_active"):
				modifier.set_meta("lab_active",modifier.active)
			modifier.active = false if raw else modifier.get_meta("lab_active")
	if raw:
		play_selected_clip()
	else:
		defender._anim.stop()
		defender._tree.active = true

func _set_model(use_student: bool) -> void:
	if show_student == use_student:
		return
	show_student = use_student
	var preserved_selection := selection
	var body_position: Vector3 = defender.position
	defender.queue_free()
	defender = _create_defender(use_student)
	defender.position = body_position
	select_move(menu.selected)

func _create_defender(use_student: bool) -> Node3D:
	var actor = preload("res://scripts/court/court_actor.gd").new()
	actor.team = 1
	actor.role = "defend"
	court.add_child(actor)
	actor.setup("guard", {"Shirt": Color(0.8, 0.12, 0.12), "Pants": Color.WHITE, "Skin": Color(0.48,0.34,0.24)}, 0, 0.0)
	foot_probe = FootFloor.new()
	foot_probe.set("body_mode", true)
	actor._skeleton.add_child(foot_probe)
	if not use_student:
		CourtPlayerModel.students = false
		actor._model.queue_free()
		actor._model = CourtPlayerModel.build({"Shirt": Color(0.8, 0.12, 0.12), "Pants": Color.WHITE, "Skin": Color(0.48,0.34,0.24)}, 0, 0.0)
		actor.add_child(actor._model)
		actor._anim = actor._model.get_node("AnimationPlayer")
		CourtPlayerModel.students = true
		actor._build_tree()
		actor._skeleton = CourtPlayerModel.find_skeleton(actor._model)
		actor._normalise_height(actor._skeleton)
	return actor

func play_selected_clip() -> void:
	var clip := selection.get_slice(" / ",1)
	if clip.begins_with("102_"):
		var id := clip.get_slice(" ",0)
		if defender._anim.has_animation("takes/"+id):
			defender._anim.play("takes/"+id)
			return
		var source_name := "defense_" + id
		var source = load("res://assets/court/%s.glb" % source_name).instantiate()
		var player: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
		var original := player.get_animation(source_name)
		var fitted := original.duplicate() as Animation
		CourtPlayerModel.Retarget.apply(fitted, CourtPlayerModel.find_skeleton(source), original, defender._skeleton)
		# The lab owns these previews; keep the shared game library untouched.
		if not defender._anim.has_animation_library("takes"):
			defender._anim.add_animation_library("takes",AnimationLibrary.new())
		if not defender._anim.has_animation("takes/"+id):
			defender._anim.get_animation_library("takes").add_animation(id,fitted)
		source.free()
		clip = "takes/"+id
	defender._anim.play(clip)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if raw:
		if not defender._anim.is_playing() and not audit:
			previous.clear()
			play_selected_clip()
	else:
		var velocity := Vector3.ZERO
		var wave := cos(elapsed * PI)
		match selection:
			"Shuffle and reverse": velocity.x = 2.5 * wave
			"Close out": velocity.z = 2.8
			"Retreat": velocity.z = -1.8
			"Diagonal recovery": velocity = Vector3(1.8 * wave,0,-1.4)
		defender.move_with(velocity,delta)
		court._user.position = defender.position + Vector3(0.22 * sin(elapsed*3),0,1.35)
		court._ball.position = court._user.position + Vector3(0.25,0.65+0.45*sin(elapsed*6),0)
		court._charging = selection == "Contest" and fmod(elapsed,2.0) > 0.65
		if selection == "Swipe":
			if court._reach.is_empty() and elapsed > 0.35:
				court._start_reach(defender)
			elif not court._reach.is_empty():
				court._reach.t += delta
				if court._reach.t > 0.5:
					court._reach.clear()
					elapsed = 0.0 if not audit else elapsed
		court._pose_all(delta)
		defender.animate(delta)
	var focus: Vector3 = defender.position + Vector3.UP
	var angle := yaw + PI if raw else yaw
	camera.position = focus + Vector3(sin(angle),0.1,cos(angle))*distance
	camera.look_at(focus,Vector3.UP)
	for side in ["L","R"]:
		var relative: Vector3 = defender.hand_position(side) - defender.shoulder_position(side)
		if raw:
			var sk: Skeleton3D = defender._skeleton
			var prefix := "Right" if side == "R" else "Left"
			relative = sk.global_transform.basis * (sk.get_bone_global_pose(sk.find_bone(prefix+"Hand")).origin - sk.get_bone_global_pose(sk.find_bone(prefix+"UpperArm")).origin)
		if previous.has(side) and elapsed > 0.35:
			max_step = maxf(max_step, relative.distance_to(previous[side]))
		previous[side] = relative
	readout.text = "Peak wrist step %.1f cm   ·   Drag to orbit, scroll to zoom" % (max_step*100)
	var sample_time := 2.5
	if raw and defender._anim.is_playing():
		sample_time = maxf(sample_time, defender._anim.current_animation_length)
	if audit and elapsed >= sample_time:
		print(selection, " peak wrist step (m): ", max_step)
		if not is_finite(max_step) or (raw and max_step <= 0.00001) or (selection == "Shuffle and reverse" and max_step > 0.10) or (selection == "Contest" and max_step > 0.20):
			failures += 1
		if menu.selected + 1 == menu.item_count:
			print("Movement audit failures: ",failures)
			get_tree().quit(int(failures > 0))
		else:
			select_move(menu.selected + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.01
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(1.8,distance-0.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(6.0,distance+0.2)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
