# Agent instructions: The U (college-sports-rpg)

Godot 4.7 project. Run tests headless:
`godot --headless --path . res://tests/<name>.tscn` (a fresh worktree needs
`godot --headless --import` once first). `dev` is the integration branch:
start new work from it.

## Animation work (court players and any 3D character)

The goal is believable early-PS2-quality athletic motion on the real skinned
character in the real game. A passing test, an IK target reached, or a valid
T-pose is not proof that it looks right.

### Rules

1. **Recorded animation owns athletic motion.** Running, cutting, jumping,
   shooting, reaching and contesting come from clips (CMU mocap and the
   library locomotion). IK and modifiers make small, bounded corrections at
   contact points. Do not build athletic motion out of corrections. If the
   source clip lacks the motion, say so and find or author a clip. Check the
   mocap catalog (`the-u-mocap-catalog` skill) before searching externally.
   **No clip? Use reference images.** Find several photographs or video stills
   of the real action, record each source and license, describe each one joint
   by joint (shoulder, elbow, wrist, hip, knee, ankle: angle and position), and
   use those as the target poses for an authored clip and as the acceptance
   reference beside the render. Commit an image only if its license allows;
   otherwise keep the link.
2. **One owner per joint, per action.** The map is
   `docs/animation/OWNERSHIP.md`. If your change alters who writes a bone,
   update the map in the same commit.
3. **Prove the layer before you edit it.** Show which layer first makes the
   pose wrong, with `tests/chain_trace.tscn` (a pose tap after every skeleton
   modifier) or an equivalent trace. Two traps:
   - Setting a modifier's `influence` from a test does not turn it off.
     `court_actor.animate()` rewrites the influence of the arm IK,
     `arm_clearance`, `elbow_hinge`, `reach_lean` and `torso_posture` every frame.
   - `get_bone_global_pose()` read between frames is the pose before the
     modifiers. Measure drawn joints through `pose_tap` (`world(side, "shoulder" | "elbow" | "hand")`).
4. **No new modifier** until you have shown that the clip and the existing
   modifiers cannot handle the problem.
5. **Proof on the rendered character.** Render before and after from the same
   cameras at the same frames: the gameplay camera and two side cameras on the
   player. `tests/contest_views.tscn` is the pattern. Pause the game for each
   screenshot, not the runner, or each view is taken frames later. Look at
   every frame of the action, including the transitions into and out of it.
   If you cannot render, say visual acceptance is unverified.
6. **Report it this way:** the observed failure and its frame; the first
   incorrect layer; the evidence; the minimum correction; the regression
   risk; the visual defects that remain. A fix is not done because tests pass.

### Order of work

Each stage must work on the real character before the next starts:
movement (idle, walk, run, slide, turn, stop) -> one player with the ball ->
two-player contact (screen, box-out, contest) -> full gameplay.

### Regression checks for animation changes

`court_checks`, `rebound_checks`, `swipe_checks`, `court_runtime_qa`,
`swipe_pose_checks`. Known failures on `dev` as of 2026-11-20:
`court_runtime_qa` 10 of 25 segments (pose pops) and `swipe_pose_checks`
0 of 36 scenarios. A change must not make either worse.

### Open animation work

- Shot contest: there is no verified recorded contest clip. The closest
  candidates in the CMU index are 13_10, 13_12 and 14_07-09 ("jump up to
  grab, reach for") and 14_20 ("reach up"). None are downloaded or reviewed.
  If none works, fall back to reference images (rule 1). References already
  gathered: Springfield College #11 (Digital Commonwealth, CC BY-SA) and three
  user-supplied NCAA photos (Arizona #35, Central Oklahoma #20, two others).
  Until there is a clip, the arm IK owns the contest arm (see OWNERSHIP.md).
- Catch, pass, screen and stance arms still have several layers moving the
  same elbow (OWNERSHIP.md, last table).
