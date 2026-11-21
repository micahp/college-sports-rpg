# Base rig certification

Certification proves the character's skeleton, skin, IK, poles, limits and
automatic corrections work on their own and together before any basketball or
football action is built on them. It applies to one rig profile at a time; the
campus student rig (`Male_Casual.fbx`, [RIG_SPEC.md](RIG_SPEC.md)) comes first.
Action tests (shooting, passing, rebounding, tackling) are not part of it.

**Status (2026-11-20): NOT CERTIFIED.** Gates 1-5 are built and run. All five
fail, and every injected fault is caught. Gates 6-8 are not built.

**Step 1 (bind pose) has been tested on branch `rig/bind-pose-import`;** see
[BIND_POSE_FIX.md](BIND_POSE_FIX.md). With `fix_silhouette` off, rest equals
bind (0 of 34 mismatched bone pairs remain) and the skin at rest matches the
modelled mesh in all 17 regions. The left elbow misplacement survives (it is
in the original rig). The results below are from the original import.

**Requirements (revised):**
- Toe bones are not required: foot contact is tested by what the rig supports.
- Leg IK is an optional capability: reported, never a gate failure.
- The 94% reach cap is a gameplay policy, reported separately from the rig's
  reach.

## Running

```
godot --headless --path . res://tests/rig/certify.tscn            # gates 1-5, each fault, the report
godot --headless --fixed-fps 60 --path . res://tests/rig/<gate>.tscn [-- fault=<name>]
godot --fixed-fps 60 --path . res://tests/rig/skin_deformation_checks.tscn    # with renders
```

Every gate exits 1 on any failed check and prints `FAILED_CHECKS: ...`.
`tests/rig/rig_fixture.gd` builds a real court actor with the game's full
modifier chain. It turns the AnimationTree off and never calls `animate()`. A
pose source at the head of the chain writes the exact input pose every frame,
into the skeleton as well, so game code reading bone poses sees it. Taps after
every modifier record each one's effect, and a gate switches on only the layers
it tests.

## Gates

| # | Gate | Scene | Status |
|---|---|---|---|
| 1 | Skeleton integrity | `skeleton_checks` | FAIL: 7 of 33 |
| 2 | Skin deformation | `skin_deformation_checks` | FAIL: 34 of 45; visual acceptance not possible until gate 1's bind defect is fixed |
| 3 | IK solvers in isolation | `arm_ik_sweep` | FAIL: 11 of 39 |
| 4 | Poles and joint limits | `pole_rotation_checks` | FAIL: 8 of 18 |
| 5 | Automatic corrections | `correction_isolation` | FAIL: 8 of 25 |
| 6 | Retarget compatibility | not built | `tests/trunk_lean_audit` and `jumpshot_fidelity` cover the trunk only |
| 7 | Dynamic integration | not built | `clip_fidelity` and `court_runtime_qa` cover parts of it |
| 8 | Evidence package | partial | this report, `certify`, renders and video below |

### Harness sensitivity

A gate that misses an injected defect cannot certify anything. `certify` runs
each gate again with every fault below. A fault counts as caught only if it
makes a check fail that passes without it.

| Gate | Fault | Caught by |
|---|---|---|
| 1 | `bone_offset`: left knee joint 5 cm low | knee and ankle mirror, thigh length |
| 1 | `axis_roll`: right forearm rest rolled 90 deg | axis mirror convention, elbow tip and hinge axes |
| 1 | `pole_axis`: IK pole read as +Z | arm IK pole axis |
| 2 | `bad_weight`: left forearm bind 10 cm off | forearm L and hand L skin |
| 3 | `pole_plus_z`: arm IK pole axis +Z | elbow never bends backward (R, L) |
| 3 | `hinge_on`: elbow_hinge left running after the IK | nothing after the IK, hand untouched, release, re-engage |
| 4 | `world_pole`: pole fixed in the world | same at every heading (R, L) |
| 5 | `rogue`: a correction turning a valid forearm 3 deg | Rogue leaves valid poses alone |

Two measurement bugs were found and fixed while building this, which is why the
self-tests exist:
- Gate 3 starts by reading back seven joints built with known angles (within
  0.2 deg). Without it, a wrongly built test pose read as a 45 deg "sideways
  elbow".
- Game code read the rest pose instead of the input (the 94% reach clamp looked
  absent) until the fixture also wrote the pose into the skeleton.

## Findings, by layer (the first wrong layer first)

### Gate 1: skeleton
1. **Rest pose is not the skin's bind pose (root cause of most of gate 2).**
   `retarget/rest_fixer/fix_silhouette/enable = true` in
   `Male_Casual.fbx.import` moved the hip and knee joints down 11.3 cm and back
   6.5-7.9 cm, the arms down 6-7.6 cm and in 3.2-3.4 cm, and the shoe controls
   down 14.5 cm. The skin binds were not updated, so:
   - at rest the shirt hangs over the shorts like a dress and the shoes tear
     into spikes (`bind_compare`);
   - the hips pivot 11.6 cm below where the skin bends;
   - `student_feet`'s `SHOE_AHEAD` and `SHOE_SCALE`, and
     `CourtPlayerModel._crotch_reweighted`, are compensating for it.

   The same FBX imported without `fix_silhouette` has rest equal to bind
   (0.0 cm).
2. Left upper arm 2.1 cm longer than the right: the left elbow joint is about
   2.6 cm too far out for the skin.
3. No toe bones (`foot_floor` is dead); the ankle joint is at the sole.
4. Passing: hierarchy, unit scale, no bone scale in any clip, body frame, limb
   axes, mirror convention, elbow and knee hinge axes, and the arm IK pole axis
   (-Z, as `POLE_AXIS_STUDENT`).

### Gate 2: skin
- At rest, measured against the mesh as modelled, the chest, pelvis, thighs,
  upper arms, shoulders, shins and feet are stretched up to 2x, and the feet
  much more (finding 1).
- Each joint's own range, measured against the rest pose:
  - The trunk, neck and head pass.
  - The shoulders and upper arms squash to 0.23-0.3x in arms-forward and across
    poses.
  - Knee lift and squat squash the thigh and pelvis to 0.24-0.39x, consistent
    with the low hip pivot.
  - With `student_feet` on, the shoes are still 1.6-2.8x from the planted shoe
    at a 120 deg knee.
- These limits (1.6x, 0.5x, 1% inverted) were set before measuring. They can't
  be judged visually until finding 1 is fixed, because the rest pose itself is
  distorted. Renders are in `build/rig/gate2/`.

### Gate 3: IK alone (no downstream repair)
- **The arm IK does not make a hinge elbow on its own.** TwoBoneIK3D aims the
  forearm's pole axis at the pole but swings the upper arm by the shortest
  rotation from the animated pose, leaving its roll inconsistent with the
  elbow. The forearm leaves the elbow's hinge plane by up to 58 deg (R) and
  46 deg (L). This is the job `elbow_hinge` does downstream, and the reason it
  runs on every offensive player every frame (gate 5).
- Humeral roll reaches 110-117 deg on side and overhead reaches with the game's
  pole rule (limit 95).
- Elbow flex reads 161-174 deg on close overhead targets, partly an artefact of
  the off-hinge forearm.
- **Pole switch pops:** `elbow_up` switches the pole instantly when the hand
  crosses shoulder height, and the elbow jumps 28-29 cm in one 2 cm target step.
  Video: frames 156→157 and 168→169 of `build/rig/ik_loop.mp4`, the arm going
  from straight to bent and back in one frame each.
- Legs (a test-only IK; **the game has no leg IK**): the knee leaves its hinge
  plane by 27-48 deg, and the right thigh rolls 57 deg.
- Passing:
  - hands and feet reach every target (0.0 cm);
  - the elbow is always on the pole's side;
  - the hand is untouched;
  - release returns exactly to the animation, and re-engaging gives the same
    answer.

### Gate 4: poles and limits
- Passing:
  - **Heading-invariant.** A full 360 deg turn while moving, and turning 4 deg
    a frame, give identical body-frame results (0.00 cm).
  - The leg IK is heading-invariant too.
  - The arm reaches up to 99.5% of the chain, and points at targets beyond it.
- Near full stretch the elbow jumps 2.8-2.9 cm per 0.5% step at 100%, and bends
  6-7 deg backward past full length.
- A target swept through the pole direction moves the elbow 31-32 cm in one
  1 deg step.
- `court_actor._clamp_hand_target` caps every reach at 94% of the chain (except
  a contest). That is a controller policy, not a rig limit, and needs a decision.

### Gate 5: corrections
| Correction | Leaves valid poses alone | Fixes its defect | Notes |
|---|---|---|---|
| crouch, reach_lean, defender_stride_arms, pose_tap | yes (0.00) | n/a (generators / read-only) | |
| foot_floor | yes | **no**: never acts | needs toe bones the rig lacks |
| foot_floor_body | yes | yes (a sunk body lands at 0.0 cm) | |
| student_feet | yes (idempotent) | follows a lifted leg (1.1 cm) | puts the shoe 3.5 cm ahead of where it was modelled |
| torso_posture | **no** | yes (a 41 deg fold becomes 15.5, legs untouched) | cuts the verified JumpShot gather lean by 20 deg and a 15 deg athletic lean by 9 deg |
| arm_clearance | **no** | yes (elbow out of the ribs) | squeezes a T-pose arm 49 deg and a 60 deg side raise 24 deg; moves the hand 3.8 cm |
| hand_aim | yes at weight 0 or on target | **no** | reaches the palm by bending the wrist 90 deg (with twist_first too): the roll belongs in the forearm |
| elbow_hinge | **no** | yes (a sideways elbow and hyperextension both fixed) | rewrites Idle arms by 52 deg, a clean anatomical hinge pose by 74 deg (elbow moved 23 cm), and JumpShot arms by 30-131 deg: its swivel search overrides valid elbows |

## Fix order (one at a time, rerunning `certify` after each)

Revised: repairing the bind pose is kept apart from removing the
compensations.

1. Repair the imported foundation and prove the unmodified skinned character is
   correct (done on `rig/bind-pose-import`, BIND_POSE_FIX.md).
2. Rebuild and verify retargeting, Idle balance, root height and scaling on the
   repaired rest: source vs retargeted vs final skinned motion. Re-measure the
   arm asymmetry.
3. Remove obsolete compensations one at a time, each only once the repaired
   base is shown not to need it.
4. Certify anatomical arm IK (hinge elbow, shoulder roll, forearm twist, no
   pole switching, near-full extension), then make `elbow_hinge` enforce
   limits only.
5. Revalidate the corrections, re-run every gate, and add gates 6-7.

The original fix order, written before the bind-pose experiment, follows.

1. **Bind pose** (gate 1, finding 1).
   - Reimport the student with `fix_silhouette` off, or rebind the skin to the
     fixed rest.
   - Then re-retarget every clip to the new rest: the library clips depend on
     the silhouette fix, and the CMU retarget and Idle balance are built on
     this rest.
   - Then remove the compensations: `SHOE_AHEAD`/`SHOE_SCALE` and the crotch
     reweight.
   - The biggest change, and it moves everything after it. Gates 2-5 must be
     rerun.
2. **Left elbow joint** (finding 2), if it survives step 1.
3. **Arm IK hinge** (gate 3).
   - Make the arm IK produce a hinge elbow itself: set the upper arm's roll
     from the pole, or solve the elbow as a hinge.
   - That lets `elbow_hinge` shrink to limits only, never a swivel search on
     clip-owned arms. This is the shooter-arm conflict in `clip_fidelity`.
4. **Pole rule** (gates 3-4): blend between the elbow-hint cases instead of
   switching, and keep the pole away from the target line.
5. **Corrections** (gate 5): `elbow_hinge`, `arm_clearance` (the wing
   limiter), `torso_posture` (after the library retarget) and `hand_aim`
   (forearm roll), each conditional so it leaves valid poses alone.
6. Decide the 94% reach policy and the toe bones / `foot_floor`, and give the
   game a leg IK only if an action needs one.
