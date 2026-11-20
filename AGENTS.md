# Agent instructions: The U (college-sports-rpg)

Godot 4.7 project. Run tests headless:
`godot --headless --path . res://tests/<name>.tscn` (a fresh worktree needs
`godot --headless --import` once first). `dev` is the integration branch:
start new work from it.

## Animation work (court players and any 3D character)

The goal is believable, controllable early-PS2-quality athletic motion on the
real skinned character in the real game, from a small, reliable animation
system shared by basketball and football. A passing test, an IK target
reached, or a valid T-pose is not proof that it looks right.

Three things are easy to conflate; keep them apart:

| Concept | Meaning | Example |
|---|---|---|
| Animation source | where a movement comes from | CMU mocap, authored keys, a procedural trajectory |
| Joint ownership | which system controls a joint at a given moment | AnimationTree, IK, a procedural controller |
| Interaction target | what the player is trying to accomplish | contest a shot, catch a ball, block a defender |

### Rule 0: the base rig and its controls must be sound first

The rig is a prerequisite, not something each animation compensates for.
Before fixing an animation or adding an interaction, check the layer it
depends on. Verify bone hierarchy, rest transforms, local axes, joint
positions, proportions, scale, skinning and retarget compatibility; the bend
plane of every IK chain and its pole convention (stable while the character
moves and turns); joint limits that allow normal athletic movement, including
near-full arm extension; and that automatic corrections (foot grounding,
torso posture, arm clearance, wrist orientation) leave already-correct poses
alone. Test each system on its own, then together, dynamically (rotate the
whole character, sweep IK targets, approach straight-arm poses, transitions),
and inspect the final skinned mesh. A failed foundation test blocks the
action work that depends on it. The rig does not need perfect anatomy: it
needs to be correct, stable and predictable for the movements the games use.

**Diagnostic order** when motion looks wrong (follow the evidence; the first
incorrect stage is the suspect, not automatically the base rig):
1. base skeleton, skinning and rest pose
2. bone axes, joint constraints and coordinate spaces
3. IK chain, pole placement and solver behaviour
4. automatic corrections and competing modifiers
5. animation source and retargeting
6. action-specific blending and interactions

### Rules

1. **Believable motion with explicit ownership.** Motion may come from recorded
   clips, authored keyframes, procedural animation, IK, or a combination.
   Choose the simplest one that looks right and supports gameplay.
   - Prefer existing motion where it fits. Clips suit locomotion, jumping,
     shooting, tackling and other complex coordinated movement; do not
     recreate them procedurally without a demonstrated reason. Check the mocap
     catalog (`the-u-mocap-catalog` skill) before searching externally.
   - Procedural motion is a valid primary source, often the right one for
     reaching, contesting, blocking, catching and reacting to objects. It needs
     a defined trajectory, anatomical limits, timing and recovery.
   - Combine sources per body part: a jump clip may own the legs and trunk
     while a procedural contest owns the arms; a run clip may own locomotion
     while a small IK correction puts a hand on the ball.
   - An IK target says where a body part goes. It does not supply shoulder
     motion, elbow bend, balance, anticipation or follow-through; the motion
     controller must.
   - **Reference images** when there is no recording, and as the acceptance
     reference for procedural motion: several photographs or video stills,
     each with source and license, described joint by joint (shoulder, elbow,
     wrist, hip, knee, ankle: angle and position). Commit an image only if its
     license allows; otherwise keep the link.
2. **One owner per joint, per action** (or a defined blend). The map is
   `docs/animation/OWNERSHIP.md`. If your change alters who writes a bone,
   update the map in the same commit. Joint ownership is not clip ownership.
3. **Corrections are conditional, bounded and declared.** Every automatic
   correction has a stated purpose, the bones it may affect, an activation
   condition and a bound, and must preserve already-correct motion. Do not
   add a downstream layer to hide a wrong rest transform, bone axis, joint
   setup or pole; do not use an action-specific exception to hide a general
   rig defect. When two systems compete over a joint, resolve the ownership.
   `tests/clip_fidelity.tscn` is the gate for clip-owned bones: it lists the
   permitted corrections (and the blend-in handoff) and fails on anything else,
   by position and by rotation (a hand in the right place with a wrongly
   twisted forearm still fails).
4. **Prove the layer before you edit it.** Show which layer first makes the
   pose wrong, with `tests/chain_trace.tscn`, `tests/clip_fidelity.tscn`
   (`stages`), or an equivalent trace. Traps:
   - Setting a modifier's `influence` from a test does not turn it off.
     `court_actor.animate()` rewrites the influence of the arm IK,
     `arm_clearance`, `elbow_hinge`, `reach_lean` and `torso_posture` every
     frame. `active = false` on the node does.
   - `get_bone_global_pose()` read between frames is the pose before the
     modifiers. Measure drawn joints through `pose_tap` or a tap modifier.
   - The student rig's bones carry scale, some mirrored. A bone's stored local
     rotation, or one quaternion from its basis, can change by up to 180 deg
     without the bone moving. Compare whole bases (`a.inverse() * b`).
   - Compare across skeletons in the body's own frame and in proportions
     (segment directions, joint angles), not raw positions: the CMU and
     student rigs split their spine and arms differently. The student's `Hips`
     is a body controller below its pelvis; use the hip-joint midpoint.
5. **No new modifier** until you have shown that the clip and the existing
   modifiers cannot handle the problem.
6. **Proof on the rendered character.** Render before and after from the same
   cameras at the same frames, through the whole action and its transitions in
   and out (`tests/shot_views.tscn`, `tests/contest_views.tscn`). Pause the
   game for each screenshot, not the runner. Run renders and comparisons with
   `--fixed-fps 60`: without it each frame takes real elapsed time and two
   runs (or two builds) drift apart. If you cannot render, say visual
   acceptance is unverified.
7. **Every action gets a spec, checked by a test.** Clip-owned joints are
   judged against the clip (`clip_fidelity`, `jumpshot_fidelity` for source to
   drawn); procedurally owned joints against their own motion spec taken from
   references, every frame (as `tests/contest_pose_check.tscn` does for the
   contest arms). "The hands reached their IK targets" is not a spec. Run the
   check against the old code too and show it fails there.
8. **Report it this way:** the observed failure and its frame; the first
   incorrect layer; the evidence; the minimum correction; the regression
   risk; the visual defects that remain. A fix is not done because tests pass.

### Order of work

Each stage must work on the real character before the next starts:
rig and controls (rule 0) -> movement (idle, walk, run, slide, turn, stop) ->
one player with the ball -> two-player contact (screen, box-out, contest) ->
full gameplay.

### Regression checks for animation changes

`court_checks`, `rebound_checks`, `swipe_checks`, `court_runtime_qa`,
`swipe_pose_checks`, `contest_pose_check`, `clip_fidelity`, `smoke`,
`season_checks`, `season_flow_checks`, and `-s res://tests/torso_posture_checks.gd`.
Compare against unchanged `dev` with the same fixtures and `--fixed-fps 60`
(court_runtime_qa is not repeatable without it). Known failures on `dev`:
`court_runtime_qa` (pose pops), `swipe_pose_checks` (0 of 36: no poke lands,
nothing is exercised), and `clip_fidelity` (the shooter's arms during the jump
shot: arm IK and hand_aim at the gather, elbow_hinge re-twisting the upper arm
and forearm, arm_clearance on the landing). A change must not add a failure.

### Open animation work

- Shooter arms on the jump shot are rewritten by four layers (clip_fidelity).
- torso_posture compensates for real defects in some clips and damages others
  (OWNERSHIP.md, "torso_posture audit"). Do not remove it globally until the
  folded clips are fixed at the retarget.
- Shot contest: no recorded contest clip. Closest CMU candidates 13_10, 13_12,
  14_07-09, 14_20 (not reviewed). References gathered: Springfield College #11
  (Digital Commonwealth, CC BY-SA) and user-supplied NCAA photos (Arizona #35,
  Central Oklahoma #20, two others). The contest arms are procedural, owned by
  the arm IK, and checked by contest_pose_check.
- Catch, pass, screen and stance arms still have several layers moving the
  same elbow (OWNERSHIP.md, last table).
