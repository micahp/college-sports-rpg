# Rebound gather

The court uses a procedural rebound on the student rig. BallPlay-M take
002_015pickle_rebound_002.pt was inspected as a movement reference. It is
not shipped or played. The SkillMimic loader stores 53 body positions and a
separate ball position and contact flag per frame. The skeleton includes
finger segments, but the presence of those channels does not establish how
individual fingers were tracked. In frame 30 the ball is at 1.30 m, the two
shoulders at 1.39–1.41 m and both elbows at 1.18–1.19 m.

The regression scene stages the same carom for three rebounders. On the
teammate replay, screenshot 091842 matches frame 169 of rebound-grip.mp4,
or frame 43 of the comparison. Both hands were already in trouble at
contact. Right wrist bend was 38.6 degrees on frame 36, 69.6 one tick later.
The upper arm stayed raised while the ball passed it.

The jump path translates the actor root. Hips, spine, clavicles and fingers
inherit the underlying animation and body modifiers. The wrist targets and
pole place the elbow. The final elbow hinge then used to search for another
upper-arm swivel, three times inside the palm-contact iteration. Hand aim
alone cannot correct an elbow on the wrong side of the ball.

Isolated baseline variants at teammate fixture frame 46, right arm, report
wrist bend in degrees and elbow height above the wrist in metres:

- Baseline 59.6 / +0.196
- Pole disconnected 10.9 / +0.014
- Palm goals cleared 40.2 / +0.215
- Final hinge modifier removed (also removes its palm correction) 15.2 / -0.008
- Torso posture removed 69.1 / +0.254

The rebound now keeps the elbow plane supplied by IK in the final hinge
pass, retains the shoulder twist and elbow flex limits, and limits hand
deflection from the forearm to 25 degrees during the gather. The palm
ramps onto the sphere over 65 ms. Other arm actions keep their original
swivel search and wrist limits.

Run tests/rebound_checks.tscn to sample the post-modifier skeleton at
60 Hz. Collision checks use palm centers and a chest plane, not finger
mesh triangles. The unanimated finger grip and limited landing compression
remain visible limitations.
