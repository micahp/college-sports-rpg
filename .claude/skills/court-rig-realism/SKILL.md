---
name: court-rig-realism
description: Prove whether a basketball court player's limbs, joints, contact points, posture or motion are physically right, using the same method as the football tackle validator (gridiron-physics tools/validate-tackles.mjs with web/mesh/interactions.js specs). Routes by aspect: segment geometry, joint range, contact points, body interpenetration, motion, posture, locomotion. Use before saying a court pose, swipe, dribble, catch or contact is right or fixed, and when the user says limbs are scaled wrong, touch points are off, a joint folds the wrong way, or something looks like a wrist flick.
---

# Court rig realism

This is the method that proved the football arms folded into the torso (a tackler's elbow
measured inside the carrier, per frame) and that gated the tackle rebuild. Copy the method,
not the numbers: football limits are design limits chosen for football, not measured data.

A passing test is not a verdict on how it looks. The user judges motion. Report numbers,
named failures and frames; never "looks natural".

## The method (from the football validator)

1. **One reference per aspect, in one place.** Football: segment offsets in
   `web/stack/skeleton.js` (JOINTS, metres), limits in `web/mesh/interactions.js` (SPECS).
   Court: `scripts/court/court_actor.gd` PROPORTIONS (segment lengths) and the limit
   constants in `tests/body_metrics.gd`. Never loosen a limit to make a test pass
   (AGENTS.md: "do not loosen validator tolerances to improve pass counts").
2. **Measure the drawn pose, not the animation.** Football reads body shapes after every
   modifier. Court: `scripts/court/pose_tap.gd` is the last modifier and game code reads
   through it. `get_bone_global_pose` is pre-modifier and gave hands 0.32 m off.
3. **Sweep scenarios; name each failure by class.** Football: 396 wrap scenarios, failures
   like `contact:hands_off_body`, `penetration:hold:arm`, `root_pop`. Scenarios the game
   would never choose are rejected, not forced. Court: 36 swipe scenarios
   (`tests/swipe_pose_checks.gd`).
4. **Report what is not gated.** Football reports planted-foot slide but does not gate on it;
   locomotion has its own check. Do the same: list it, don't hide it.
5. **Localise the fault.** Football measured elbow SDF inside the carrier per frame and named
   the body part. Court equivalent: name the arm, the joint, the frame and the angle
   (`elbow over-flexed 146 deg`, `arm 52 deg behind the body`).

## Route by aspect

| Aspect | Reference | What to assert | Court check | Status |
|---|---|---|---|---|
| Segment lengths | skeleton.js JOINTS offsets; PROPORTIONS | thigh 0.45, shin 0.43, upper arm 0.29, forearm 0.26, each within 3% | `tests/body_scale_check.gd` prints only | **assert not written** |
| No stretch | rest lengths | each bone's distance to its parent equals rest length within 1 mm, every frame | none | **not written** |
| Joint range (elbow, knee, wrist, shoulder) | human ranges, `body_metrics.gd` | elbow -10..150 deg, sideways <25 deg; wrist bend <60, twist <90; upper arm <85 twist, <25 behind side plane | `tests/body_metrics.gd`, `swipe_pose_checks.gd` | elbow, shoulder, wrist done; knee not |
| Contact points (palm, hand) | body shape, tolerance | palm within 4 cm of the ball, sink under 2 cm, palm faces the ball within 60 deg | `tests/swipe_pose_checks.gd` | swipe only; dribble not |
| Interpenetration | body shapes, penetration limit | no body part inside another by more than the limit | `tests/contact_checks.gd` (ball in body, torso overlap) | written, not gated per frame |
| Motion and pops | root_speed limit | palm moves <0.20 m per frame relative to shoulder; peak 3 to 10 m/s | `tests/swipe_motion_checks.gd`, POP listing with `-- pops` | limits are my estimates |
| Posture | none in football | trunk lean and head height per phase | lean measured only | **no limit** |
| Locomotion and feet | football reports slide only | planted feet within 1 cm of floor | `tests/court_runtime_qa.gd` (fails on pose pops, see gaps) | not gated |

## Procedure
1. Name the aspect the user raised; route to its row. A pass on one row says nothing about another.
2. Run that row's check. Report every failure with its class, the joint, the frame and the number.
3. Cut consecutive frames of the moment (watch-video skill), cropped to the players, and describe
   what each frame shows. Frames are stills; say so.
4. List the rows not yet asserted that bear on the complaint.
5. Leave the judgement of motion to the user.

## Picture-first review (use when the user shows a screenshot or video)

The user judges by looking. Match that before running numbers.

1. Open the picture and describe the target player first: which player, which team,
   what they are doing, and which part of the body the complaint is about.
2. For that body part, list each visible bone and joint: shoulder, elbow, wrist, hip,
   knee. Give an angle estimate for each joint and say it is an estimate from a still.
   Say where each hand is relative to the ball or the head.
3. Say what the picture cannot show: occlusion (another player in front), resolution,
   camera angle. Name the hidden part instead of guessing it.
4. Get reference photos of the real action (licensed images or ones the user supplies)
   and describe them with the same list, so the descriptions line up joint by joint.
   Check which player is which first: on the court the user's team (NVS) wears
   yellow and the opponent wears red, so a contesting defender is in red.
   When no CMU clip exists, these photos are the reference for authoring the
   motion too (see `the-u-mocap-catalog`, "When no CMU clip exists").
5. Put the two side by side in one image (Pillow is installed) and show it to the user.
   If no reference can be found, say so and ask the user for one; do not invent a reference.
6. Only then run the numeric check for that row, and report both.

## Trace the modifier chain before blaming a layer

The arm pose is built by many SkeletonModifier3D layers in skeleton child order
(court_actor.gd setup): crouch, foot_floor, student_feet, foot_floor (body), torso_posture,
reach_lean, defender_stride_arms, TwoBoneIK3D R, TwoBoneIK3D L, arm_clearance, hand_aim R,
hand_aim L, elbow_hinge, pose_tap. Several of them move the same elbow.

- Use `tests/chain_trace.tscn` (a PoseTap inserted after every modifier) to see what each
  stage did to the shoulder, elbow and hand. Run it once with `notaps` to confirm the taps
  change nothing.
- Do not ablate by setting `influence = 0` from a test: `court_actor.animate()` rewrites the
  influence of the arm IK, arm_clearance, elbow_hinge, reach_lean and torso_posture every frame,
  so the change is undone before the modifiers run.
- `tests/body_metrics.gd arm()` reads `get_bone_global_pose` between frames, which is the pose
  BEFORE the modifiers. Measure drawn joints through `pose_tap.world(side, "shoulder"|"elbow"|"hand")`.
- `elbow_hinge.gd` has `debug_print`: it prints every swivel it tried with its shoulder twist,
  backward angle and cost. That is how to see why it moved an elbow.
- Check which way the body faces against where the hands are aimed: `lock_face` and the hand
  goals come from different code.

## Known gaps
- Segment-length and no-stretch assertions are not written. Those would have caught the
  limbs being scaled wrong before the user did.
- Palm touch point is an 8 cm guess from the wrist bone, not measured from the mesh. The
  football hand has real knuckle joints (`fiR`, `fi2R`, `thR` in skeleton.js); court has none.
- Hip height is about 7% below the reference; cause not found.
- Runtime QA gave identical output before and after the proportion fit, so it cannot judge
  proportions. Do not use it for that.
- Court limits (trunk, swipe speeds) are estimates; football limits are design choices. Neither is measured basketball data.
