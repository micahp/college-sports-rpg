# Court player bone ownership

Who writes which bones, in the order they run each frame. Built in
`scripts/court/court_actor.gd` (`setup()` adds the modifiers to the skeleton
in this order; `animate()` turns them on and off every frame).

Rows marked **measured** were traced with `tests/chain_trace.tscn`. The rest are
read from the code and still need a trace.

## Pipeline

| # | Layer | Bones it writes | When it runs | Overwritten later by |
|---|---|---|---|---|
| 1 | AnimationTree (`_build_tree`) | every bone (local poses). Gait clip; `guard` / `stance_arms` blends on the arm tracks (Idle / GuardHold); `carry` = DribbleRun arms; `upper` one-shot (Reach, Pass, Clap) on arm tracks; `swipe` one-shot on arms, legs, spine, neck, head; `shot` one-shot (jump shot, layup, jump) on everything | always | everything below |
| 2 | `crouch.gd` | UpperLeg, LowerLeg, Foot (both); Hips height | `amount > 0`: defensive stance at Idle/Backpedal, or `crouch_goal` | 3, 5 |
| 3 | `foot_floor.gd` (foot mode) | LeftFoot, RightFoot (lift only, at most 6 cm) | a foot is under the floor | 4 |
| 4 | `student_feet.gd` | Foot.L, Foot.R control bones (student rig only) | always on the student rig | 5 |
| 5 | `foot_floor.gd` (body mode) | Hips (raise at most 12 cm), Foot.L, Foot.R | the drawn shoe mesh is under the floor | none |
| 6 | `torso_posture.gd` | Spine (trunk lean over 6 degrees is compressed to 27%) | always, except while a `TRUNK_VERIFIED` action clip plays (JumpShot); fades with the clip's blend in and out | 7 |
| 7 | `reach_lean.gd` | Spine (lean, twist), Neck | a swipe sets `lean_amount` / `twist`; off in the swipe chain | none |
| 8 | `defender_stride_arms.gd` | LeftUpperArm, RightUpperArm | idle hands while walking or running forward | 9, 10, 12 |
| 9 | `TwoBoneIK3D` R, L | UpperArm, LowerArm (hand reaches the target) | influence = hand weight (`w_r`, `w_l`); target = `hand()` goal clamped to reach; pole = shoulder + `elbow_hint()` x 0.6 | 10, 12 |
| 10 | `arm_clearance.gd` | UpperArm, LowerArm (swings the elbow and forearm out of a torso ellipse; squeezes arms out wide). **Moves the hand.** | always, except the swipe chain and a shot contest (`skip_arms`) | 12 |
| 11 | `hand_aim.gd` R, L | Hand (rotation only: palm toward a point) | `palm_to()` weight, or the dribbling hand | 12 |
| 12 | `elbow_hinge.gd` | UpperArm, LowerArm, Hand. Keeps shoulder and wrist, **re-chooses the elbow swivel** by cost (shoulder twist over 85 degrees, arm behind the body, inside the torso, distance from the pose's elbow, last frame), then rebuilds the hinge, forearm twist and wrist limits. Then `palm_on()` contact, which swings the whole arm. | not in the swipe chain, and not idle hands without palm goals. No swivel search with `rebound_grip` or `keep_swivel` | none |
| 13 | `pose_tap.gd` | none (reads) | always. Game code reads drawn hands, elbows and shoulders here; `get_bone_global_pose` between frames is the pose before layers 2-12 | none |

## Arm IK pole axis (rig foundation, 2026-11-20)

`TwoBoneIK3D` aims one local axis of the forearm bone at the pole. On the
campus student rig the elbow tip is the forearm's -Z (measured over every bent
elbow in the court clips); the code used +Z, the axis the forearm folds toward
(elbow_hinge's `front_of`, which is right). So every IK solve rolled the arm
about half a turn: hand and elbow in the right place, upper arm and forearm
twisted 150-170 deg from the clip. elbow_hinge was twisting them back, and
every handoff from IK to clip blended across that half turn: the 15-20 m/s
hand pop at dribble -> stance. Now `POLE_AXIS_STUDENT` (-Z). The handoffs also
fade instead of switching: elbow_hinge and hand_aim over CORRECTION_FADE, and a
releasing IK keeps its last target and pole in the body's frame.

## Jump shot: source to drawn (tests/jumpshot_fidelity, 2026-11-20)

The CMU clip, the retargeted student clip, the AnimationTree output and the
drawn pose, at the same clip times, in the body's frame:

- Retarget: limbs exact (elbow, knee, shoulder elevation, palm direction,
  segment directions). Trunk was wrong: the CMU Neck sits on its UpperChest,
  so the student's 36 cm upper torso was aimed along the CMU head (up to 9 deg
  of extra roll). Fixed: `MocapRetarget._trunk_top` puts the student's neck on
  the source's pelvis-to-neck line. Trunk pitch and roll now within 1 deg.
  Remaining: the chest bone's facing differs by a constant ~10 deg (rest
  shapes differ); the hip line differs by up to 8 deg before the game's start
  point in the clip (0.35 s).
- AnimationTree: differs from the clip only in the one-shot's blend in
  (0.12 s) and out (0.2 s). The blend out replaces the last 0.2 s of the
  landing recovery with the gait pose.
- Modifiers: torso_posture was the only layer changing the trunk (gather lean
  19 -> 6 deg; it also hid part of the retarget's roll error). Now off for
  JumpShot. The arms: see clip_fidelity failures below.

## torso_posture audit (tests/trunk_lean_audit, 2026-11-20)

Worst trunk difference from the recording on the student rig, and what
torso_posture removes (mean / max deg):

| Clips | Retarget | Trunk vs recording | torso_posture removes | Verdict |
|---|---|---|---|---|
| DribbleRun, SlideL/R, Backpedal, JumpShot, Layup | ours (CMU) | within 2 deg (Layup roll 6) after the trunk fix | 0 to 24 / up to 37 | it damages these; only JumpShot is exempt so far |
| Idle, Walk, Clap, Reach | library, copied bone for bone | 13 deg too far forward | 9-12 / 10-13 | genuinely folded: needs a retarget change (branch exp/library-retarget) |
| Jog, Sprint | library, copied bone for bone | 15 deg pitch and roll | 24-33 / 28-36 | genuinely folded |
| JogM, Run | engine import retarget | 11-13 deg | 7-10 / 9-12 | genuinely folded |
| SwipeCMU | ours, then rebuilt from Idle's trunk | 13-18 deg (by design) | 10 / 10 | inherits Idle's fold |

torso_posture cannot be retired until the folded clips are fixed at the
retarget: it is the only thing hiding them.

## Shooter arms during the jump shot (tests/clip_fidelity)

OWNERSHIP says the clip owns the arms on a shot. Four layers change them:
arm IK and hand_aim at the gather (frames 1-9: the dribble hand handing over,
past the 0.12 s blend), elbow_hinge on every frame (re-twists the upper arm and
forearm 6-47 deg while keeping the hand), arm_clearance on the landing (upper
arm up to 40 deg, a hand 37 cm off). Not fixed; clip_fidelity fails on them.

## Where layers compete

- **Elbow:** layers 8, 9, 10 and 12 all set it. Layer 12 runs last, so its
  swivel choice wins unless `keep_swivel` or `rebound_grip` is set.
- **Hand position:** layer 9 puts it on the goal; 10 moves it by turning the
  upper arm; 12's palm contact moves it again.
- **Spine:** 6 then 7 (7 is written to survive 6; the comment in `reach_lean.gd` says why).
- **Hips and feet:** 2, then 3, 4 and 5.
- **Arm length cap:** `court_actor._clamp_hand_target` keeps every hand goal
  within `arm_length`, which is 94% of the bone chain. That alone keeps every
  arm bent at least ~40 deg. Only the contest is allowed past it (112%, so
  the IK straightens the arm). Catches, passes and rebounds still have the cap.
- **Palm twist:** `hand_aim` (11) turns the palm, then `elbow_hinge` (12)
  re-splits the hand's twist between forearm and wrist and caps the forearm
  at 88 deg. With hand_aim's single shortest rotation and that cap, a raised
  contest palm was turned back out to the side by up to 37 deg or tipped to
  the sky. Contest only: hand_aim `twist_first` (twist about the forearm, then
  a small wrist bend) and the hinge moves excess twist into the shoulder
  (`keep_swivel`). The dribble hand and other actions still use the old path:
  turning it on for the dribble added pose pops in `court_runtime_qa`.
- **Facing vs aim:** `court_game.gd` sets facing (`lock_face`) and hand goals
  in separate code. They must use the same target.

## One owner per joint, by action

| Action | Hand | Elbow | Status |
|---|---|---|---|
| Shot contest | IK (9), target straight overhead past full reach; palm: hand_aim (11) twist-first toward the ball at the release point, and the hinge (12) puts twist the forearm cannot take into the shoulder | IK pole (9), forward and slightly out; hinge only enforces limits (`keep_swivel`); clearance off; faces the shooter | **measured and gated** (2026-11-20, `contest_pose_check`: elbow bend 9-10 deg frames 16-80) |
| Swipe | baked clip (1) | baked clip (1); IK, clearance, hinge, lean all off | read from code |
| Rebound | IK (9) + palm contact (12) | IK pole (9); hinge `rebound_grip` (no swivel) | see `rebound-gather.md` |
| Dribble | clip arms (1) + IK on the ball hand (9), pole follows the animated elbow | clip | read from code |
| Catch, pass, screen, stance, calling for the ball | IK (9), then clearance (10) | IK pole, then clearance, then hinge swivel (12) | **still multiple owners**: next to fix |

### Legs and hips, by action

| Action | Legs and hips | Status |
|---|---|---|
| Defender jump (shot contest, layup block, pass pick-off) | CMU `JumpShot` clip (1) via `court_game._defender_jump` (start 0.55 s or 0.62 s, speed 1.2) | **measured** (2026-11-20, `tests/leg_trace` + contest_views) |

Do not use the library `Jump` clip (`Jump_Start`) on the court. It expects the
engine to lift the body. The court never does, so the feet tuck 0.5-0.66 m up
under hips that stay at standing height and the player looks like he sinks to
the floor. `tests/leg_trace.tscn` prints hip height, knee flex and foot height
after every modifier, per frame.
