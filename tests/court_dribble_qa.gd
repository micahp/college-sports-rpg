extends Node3D
## Dribble QA against the original recording. Drives one player with the ball
## at steady speeds and logs every dribble's real timing and hand heights.
## Truth (CMU 06_02, a real player and ball): hand on the ball 0.40 s, ball
## away 0.60 s, hand 0.77 m at release and 1.03 m at the catch, at the
## clip's own pace; both times shrink in proportion when it plays faster.
##
##   godot --headless --fixed-fps 60 tests/court_dribble_qa.tscn

const Actor = preload("res://scripts/court/court_actor.gd")
const PLAN: Array = [["standing", 0.0], ["walk 1.4", 1.4], ["jog 2.7", 2.7], ["run 3.6", 3.6], ["sprint 4.7", 4.7]]
const SECONDS: float = 6.0

var _actor: Node3D
var _step: int = -1
var _left: float = 0.0


func _ready() -> void:
	Actor.dribble_log = true
	_actor = Actor.new()
	add_child(_actor)
	_actor.setup("", {}, 0, 0.15)
	_actor.is_user = true
	_next()


func _next() -> void:
	_step += 1
	if _step >= PLAN.size():
		get_tree().quit(0)
		return
	_left = SECONDS
	print("SEG %s" % PLAN[_step][0])


func _physics_process(delta: float) -> void:
	if _step >= PLAN.size():
		return
	_actor.pose_reset()
	_actor.has_ball = true
	_actor.move_with(Vector3(0, 0, -float(PLAN[_step][1])), delta, 16.0)
	_actor.animate(delta)
	_actor.dribble_ball(delta, 0.13)
	_left -= delta
	if _left <= 0.0:
		_next()
