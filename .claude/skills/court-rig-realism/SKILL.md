---
name: court-rig-realism
description: Research how complete basketball actions actually move using coaching fundamentals, continuous real-game footage and available mocap, then validate the full skinned movement and contact in Godot. Use before creating or diagnosing rebounds, shots, dribbles, closeouts, screens, passes, catches, cuts, footwork, transitions, or when a pose or physical contact looks wrong. Includes the joint/limb validator workflow.
---

# Court rig realism

This is the method that proved the football arms folded into the torso (a tackler's elbow
measured inside the carrier, per frame) and that gated the tackle rebuild. Copy the method,
not the numbers: football limits are design limits chosen for football, not measured data.

A passing test is not a verdict on how it looks. The user judges motion. Report numbers,
named failures and frames; never "looks natural".

## Research the sport before authoring the movement

**This is required when building or changing any basketball action**, not only when debugging a wrong joint. A valid skeleton and plausible-looking individual poses do not establish that a rebound, screen, closeout, shot, pass, pivot, cut or landing moves like basketball. Study the whole action and its game situation before deciding which clip, IK control or procedural motion to use. See `the-u-mocap-catalog` for local clip inventory and `watch-video` for examining consecutive frames.

### Where to find trustworthy basketball movement references

Research by action name and game context, e.g. `defensive rebound box out contact jump catch land outlet`, `offensive rebound tip-in second jump`, `defensive closeout decelerate slide`, rather than only `rebound animation`. Use this order:

1. **Coaching fundamentals (what the action accomplishes).** Read an applicable Jr. NBA, USA Basketball, or FIBA/WABC coaching resource. Extract positioning, footwork, body control, contact and decision-making instructions. Coaching points are qualitative, not measured joint-angle or timing data.
2. **Continuous real basketball footage (what the whole body actually does).** Find a real NCAA, NBA, FIBA or practice/drill sequence showing the athlete *before, during and after* the action. Prefer an uninterrupted view with feet, pelvis, torso, hands and ball visible. A highlight that cuts away after a shot is not a complete rebound reference.
3. **Existing game assets and captured motion (what can be implemented).** Check `the-u-mocap-catalog`, source recordings, local clips and the actual Godot retarget/ownership rules. A recorded clip can supply the movement but may not contain real ball contact, fingers or the complete interaction.
4. **Basketball video games (style and implementation comparisons only).** Use NBA 2K2, NBA Live 2003 or other era-appropriate games for animation complexity, staging, transitions and camera-level readability *after* verifying their specific motion visually. Do not import their rebound-winning logic, timing, AI decisions or statistical outcomes as basketball fundamentals. NBA Live 2001 in particular is not an authoritative rebounding-mechanics source.
5. **Photographs and stills (pose supplements).** Use them to verify positions and silhouettes but not to infer movement timing, foot plants, contact order or transitions that a static image cannot show.

Verified source starting points (browse the specific action page, do not assume it contains a usable full-body clip):

- Jr. NBA, Chris Bosh rebounding breakdown: https://jr.nba.com/chris-bosh-shows-you-how-to-rebound/ (find opponent, shield with body, jump/reach).
- Jr. NBA, rebounding fundamentals: https://jr.nba.com/rebounding/ (position, bend knees, shield, jump, then outlet or putback according to possession).
- Jr. NBA, Frank Vogel box-out video page: https://jr.nba.com/video/how-to-box-out-and-rebound/ (video availability and exact contents still require direct inspection).
- Jr. NBA rebounding topic index: https://jr.nba.com/category/basketball-skills-and-drills/rebounding/
- USA Basketball player fundamentals: https://www.usab.com/skills-drills-players-foundational ; footwork/body control: https://www.usab.com/play/player-resources/skills-drills-players-foundational-footwork
- USA Basketball coaching courses: https://www.usab.com/coaching/e-learning (includes rebounding/screening instruction; access and course contents may vary).
- FIBA/WABC coaching manuals directory: https://about.fiba.basketball/en/wabc-documents (find the relevant defensive, offensive and footwork chapters; the index alone is not evidence of their details).

These are discovery starting points, not a claim every link contains a downloadable clip or universally applicable movement. Record exactly what was read or viewed and when. If the named page is inaccessible, search the official site's equivalent before substituting another source.

### Turn the research into an actionable full-body motion brief

Before implementing or repairing an action, write a compact action brief in the task/review notes. It must have:

- **Action and context:** offensive vs defensive, moving vs stationary, player/ball/opponent positions, intended outcome, variants. A defensive box-out rebound differs from a weak-side offensive putback.
- **Sources with evidence:** title, URL, exact segment/time range or still frame, what it demonstrates, limitations/occlusions and license or permission status. Separate a coach's written instruction from motion actually observed in video.
- **Complete phase timeline:** starting stance/approach; footwork and positioning; load and weight transfer; jump/turn/reach; first true contact; gather/landing; recovery and next action. Mark which phases are conditional or absent. Do not manufacture exact seconds or angles from prose.
- **Whole-body responsibilities at each phase:** root and feet (plants, steps, takeoff, landing), pelvis/hips and knees (load, balance), chest/trunk and head (direction, rotation, ball clearance), shoulders/elbows/wrists and hands (reach, contact, secure), ball and opponent trajectories. Include where weight is supported and what should remain stable.
- **Contact and state transitions:** what makes a catch or block physically possible, when possession or contact changes state, and how the body and ball transition without teleporting or clipping. A shoulder-to-ball *reachability* test is not evidence that the palms made contact.
- **Implementation choice:** existing clip, edited clip, authored keys, IK, procedural control or hybrid; explicit joint ownership and transition into/out of locomotion. No new correction layer just to approximate a reference.
- **Observables and uncertainties:** frame-accurate planted-foot and hand/ball contact order when video supports them, approximate angles clearly labelled as estimates, known occlusions, and what has not been verified.
- **Acceptance and comparison:** full-body final skinned motion at normal speed plus consecutive-frame sheets; source clip/reference side-by-side where possible; continuous trajectories, sound footwork and weight transfer, ball/head/torso separation, no unfair action-specific fudging. Document differences from the source.

Do not start with an isolated hand target and retrofit legs/trunk later. Do not treat a passed elbow or grip test as proof that the athletic action is correct. Keep realistic movement distinct from game balance or which player wins possession.

### Rebounding worked example (apply the method, not a universal fixed animation)

Use the Jr. NBA Bosh lesson and basic rebounding guidance to define *possible* phases: identify opponent/ball; establish position or box out with feet, hips and trunk; load and jump/step; reach to the descending ball; make actual hand contact; gather and protect the ball; absorb landing; transition to outlet, dribble or putback. Not every rebound has a box-out, two-handed catch or the same landing.

Measure the *entire rebounder*, not only hands: foot placement and center-of-mass shift before takeoff; hip/knee extension and timed trunk/arm reach; catch eligibility versus actual palm contact; ball path around the head into a secure position; knee/hip landing compression and pivot/outlet. When a rebound is awarded before hands reach the ball, fix the contact decision before disguising it with a decorative gather trajectory.

Do not automatically lower a wrist-forward requirement during a post-contact gather; instead test reach, contact, gather and landing as distinct phases. Conversely, do not demand outstretched wrists *after* the ball is secured. Review both successful and unsuccessful rebound attempts when available.

### Review and rights rules

- Use `watch-video` to inspect every consecutive frame through contact and transitions, including the start and recovery; a few screenshots are inadequate. Crop to keep the feet, pelvis, trunk, arms, head and ball visible together. Supplement with closeups, not replace the full-body view.
- Compare source/reference and the final skinned character from suitable cameras; do not infer 3D joint coordinates or physical contact from one obstructed broadcast angle. Test in-game context as well as isolated clips.
- Treat validation thresholds as hypotheses until tied to reference footage, anatomy or gameplay requirements. Never loosen a check solely to pass a regression.
- Keep public/reference footage linked with timestamp and license. Do not commit, redistribute or embed copyrighted footage or photos without permission; inspect rights before retaining local reference files.
- If no reliable full action is available, say which portions are unverified. Author only the supported parts and request targeted footage if indispensable; never fabricate a complete motion from a still.


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
4. Follow the basketball movement research workflow above: identify the action and its
   phases, find coaching instruction and continuous real motion where possible, then add
   licensed photos/stills to clarify joint positions. Match the same body parts in each.
   Check who is who: NVS wears yellow and the opponent red in the current court scene.
   See `the-u-mocap-catalog` for source motion availability and `watch-video` for timing.
5. Show full-body source and render side by side (Pillow where useful), with the same
   phase and approximate view, then inspect consecutive frames. A still comparison
   can certify a pose but not a whole action. State what is occluded or unavailable.
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
- Historical hip-height and proportions notes predate the bind-pose import investigation; remeasure the active branch against `docs/animation/RIG_CERTIFICATION.md` before relying on them.
- Runtime QA gave identical output before and after the proportion fit, so it cannot judge
  proportions. Do not use it for that.
- Court limits (trunk, swipe speeds) are estimates; football limits are design choices. Neither is measured basketball data.
