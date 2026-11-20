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
| 6 | `torso_posture.gd` | Spine (trunk lean over 6 degrees is compressed to 27%) | always (influence eases to 1) | 7 |
| 7 | `reach_lean.gd` | Spine (lean, twist), Neck | a swipe sets `lean_amount` / `twist`; off in the swipe chain | none |
| 8 | `defender_stride_arms.gd` | LeftUpperArm, RightUpperArm | idle hands while walking or running forward | 9, 10, 12 |
| 9 | `TwoBoneIK3D` R, L | UpperArm, LowerArm (hand reaches the target) | influence = hand weight (`w_r`, `w_l`); target = `hand()` goal clamped to reach; pole = shoulder + `elbow_hint()` x 0.6 | 10, 12 |
| 10 | `arm_clearance.gd` | UpperArm, LowerArm (swings the elbow and forearm out of a torso ellipse; squeezes arms out wide). **Moves the hand.** | always, except the swipe chain and a shot contest (`skip_arms`) | 12 |
| 11 | `hand_aim.gd` R, L | Hand (rotation only: palm toward a point) | `palm_to()` weight, or the dribbling hand | 12 |
| 12 | `elbow_hinge.gd` | UpperArm, LowerArm, Hand. Keeps shoulder and wrist, **re-chooses the elbow swivel** by cost (shoulder twist over 85 degrees, arm behind the body, inside the torso, distance from the pose's elbow, last frame), then rebuilds the hinge, forearm twist and wrist limits. Then `palm_on()` contact, which swings the whole arm. | not in the swipe chain, and not idle hands without palm goals. No swivel search with `rebound_grip` or `keep_swivel` | none |
| 13 | `pose_tap.gd` | none (reads) | always. Game code reads drawn hands, elbows and shoulders here; `get_bone_global_pose` between frames is the pose before layers 2-12 | none |

## Where layers compete

- **Elbow:** layers 8, 9, 10 and 12 all set it. Layer 12 runs last, so its
  swivel choice wins unless `keep_swivel` or `rebound_grip` is set.
- **Hand position:** layer 9 puts it on the goal; 10 moves it by turning the
  upper arm; 12's palm contact moves it again.
- **Spine:** 6 then 7 (7 is written to survive 6; the comment in `reach_lean.gd` says why).
- **Hips and feet:** 2, then 3, 4 and 5.
- **Facing vs aim:** `court_game.gd` sets facing (`lock_face`) and hand goals
  in separate code. They must use the same target.

## One owner per joint, by action

| Action | Hand | Elbow | Status |
|---|---|---|---|
| Shot contest | IK (9) | IK pole (9); hinge only enforces limits (`keep_swivel`); clearance off; faces the shooter | **measured** (2026-11-20, chain_trace + contest_views) |
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
