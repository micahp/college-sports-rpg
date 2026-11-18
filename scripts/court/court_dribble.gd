class_name CourtDribble
extends RefCounted
## One dribble as a curve: the ball is pushed down from the hand, bounces
## once under gravity and comes back up into the hand, which rides it to the
## top and pushes again. The sprite bake puts the dribbling hand on this
## curve and the game moves the ball along the same curve, so hand and ball
## always agree. Heights are for a 1.81 m player, ball centre above the floor.

const RADIUS: float = 0.12
const Y_RELEASE: float = 0.88
const Y_CATCH: float = 0.84
## Where the ball bounces relative to the player (model space: -x is his right).
const LOCAL: Vector3 = Vector3(-0.30, 0.0, 0.32)
const GRAVITY: float = 9.81
const BOUNCE: float = 0.78
const SAMPLES: int = 48


## period: seconds per dribble. Returns ball and hand heights sampled over
## one dribble (phase 0 = the hand meets the ball), the share of the dribble
## the hand is on the ball, and the phase of the bounce.
static func table(period: float) -> Dictionary:
	var contact: float = 0.42
	var fit: Array = []
	while contact < 0.8:
		fit = _solve(Y_RELEASE, Y_CATCH, (1.0 - contact) * period)
		if not fit.is_empty():
			break
		contact += 0.03
	if fit.is_empty():
		fit = [0.15, 2.0]
	var span: float = (1.0 - contact) * period
	var tb: float = fit[0]
	var v0: float = fit[1]
	var v_catch: float = BOUNCE * (v0 + GRAVITY * tb) - GRAVITY * (span - tb)
	var hold: float = contact * period
	var ball: Array = []
	var hand: Array = []
	for i in SAMPLES:
		var phase: float = float(i) / SAMPLES
		var by: float
		var hy: float
		if phase < contact:
			by = _hermite(Y_CATCH, v_catch, Y_RELEASE, -v0, hold, phase / contact)
			hy = by + RADIUS + 0.02
		else:
			var t: float = (phase - contact) * period
			if t <= tb:
				by = Y_RELEASE - v0 * t - 0.5 * GRAVITY * t * t
			else:
				var up: float = t - tb
				by = RADIUS + BOUNCE * (v0 + GRAVITY * tb) * up - 0.5 * GRAVITY * up * up
			by = maxf(by, RADIUS)
			hy = _hermite(Y_RELEASE, -v0 * 0.35, Y_CATCH, v_catch * 0.35, span, t / span) + RADIUS + 0.02
		ball.append(snappedf(by, 0.001))
		hand.append(snappedf(hy, 0.001))
	return {"ball": ball, "hand": hand, "contact": contact, "bounce": contact + tb / period}


static func sample(values: Array, phase: float) -> float:
	var n: int = values.size()
	var x: float = fposmod(phase, 1.0) * n
	var i: int = int(x) % n
	return lerpf(float(values[i]), float(values[(i + 1) % n]), x - floorf(x))


static func _hermite(p0: float, m0: float, p1: float, m1: float, dur: float, s: float) -> float:
	var s2: float = s * s
	var s3: float = s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * p0 + (s3 - 2.0 * s2 + s) * dur * m0 \
		+ (-2.0 * s3 + 3.0 * s2) * p1 + (s3 - s2) * dur * m1


## Time to the floor and downward launch speed for a ball that leaves at y0,
## bounces once and is at y1 after `span` seconds.
static func _solve(y0: float, y1: float, span: float) -> Array:
	var prev_err: float = 0.0
	var have_prev: bool = false
	for k in range(1, 200):
		var tb: float = span * k / 200.0
		var v0: float = (y0 - RADIUS - 0.5 * GRAVITY * tb * tb) / tb
		if v0 < 0.0:
			continue
		var up: float = span - tb
		var err: float = RADIUS + BOUNCE * (v0 + GRAVITY * tb) * up - 0.5 * GRAVITY * up * up - y1
		if have_prev and (err > 0.0) != (prev_err > 0.0):
			return [tb, v0]
		prev_err = err
		have_prev = true
	return []
