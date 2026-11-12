extends Node
## Lists scene nodes near the Rec Center steps, to find what the blue pole is.

func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(30)
	var steps: Vector3 = Vector3(0.0, 0.0, -15.0)
	_walk(loc, Vector3(4.2, 0.0, 1.6))
	get_tree().quit(0)


func _walk(n: Node, steps: Vector3) -> void:
	if n is Node3D and n.name != "Actors":
		var d: float = Vector2((n as Node3D).global_position.x - steps.x, (n as Node3D).global_position.z - steps.z).length()
		if d < 2.0 and (n.name.begins_with('Hargrove') or n.name.begins_with('Moreno') or n.get_class() in ['StaticBody3D','CollisionShape3D'] or n.name.begins_with('door') or n.name.begins_with('Door') or n.name.begins_with('Building') or n.name.begins_with('Prop') or n.name.begins_with('Bench') or n.name.begins_with('Tree')):
			print("near: %-28s %-22s at (%.2f, %.2f, %.2f) d=%.2f" % [
				str(n.get_path()).substr(0, 60), n.get_class(), n.global_position.x, n.global_position.y, n.global_position.z, d])
	for c in n.get_children():
		_walk(c, steps)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
