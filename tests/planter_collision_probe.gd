extends Node
## Casts rays across the Rec Center planters in the campus scene to confirm
## they block movement.

func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(40)
	var space: PhysicsDirectSpaceState3D = loc.get_world_3d().direct_space_state
	for name in ["PlanterL", "PlanterR", "PlanterWest", "PlanterEast"]:
		var planter: Node3D = loc.find_child(name, true, false)
		if planter == null:
			print(name, " missing")
			continue
		var c: Vector3 = planter.global_position
		var from: Vector3 = c + Vector3(0.0, 0.3, -2.5)
		var to: Vector3 = c + Vector3(0.0, 0.3, 2.5)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		print(name, " blocks ray: ", not hit.is_empty(), " at ", c)
	get_tree().quit(0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
