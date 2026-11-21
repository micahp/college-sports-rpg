---
name: the-u-mocap-catalog
description: Motion-capture coverage for The U (Godot basketball game). Use before adding, changing, or diagnosing any basketball animation, before searching CMU for a clip, or when asked whether a game action already has usable mocap. Points to the catalog and coverage registry the repo should keep, and lists the audit questions to answer from the code and assets.
---

# The U: motion-capture catalog and coverage

Purpose: stop treating every missing animation as a new research task. Answer from
the repo first (what exists, what is imported, what works, what is missing), then
search CMU only for gaps.

## Status of this skill

The CMU clip groups below come from a research summary. They are **candidates, not
verified**. Before relying on one, confirm the file exists in the CMU source and that
it has been imported and visually reviewed in this repo.

The CMU collection has about 2,605 recorded trials. Most are not indexed in this repo
yet. Only a small subset (subjects 6, 78, 102, 124, plus a few others) has been
discussed so far. Index the rest before treating a gap as "no data exists."

## Sources

- CMU Graphics Lab motion capture database: https://mocap.cs.cmu.edu/
- CMU BVH collection (GitHub): https://github.com/una-dinosauria/cmu-mocap
- Machine-readable index: https://github.com/una-dinosauria/cmu-mocap/blob/master/cmu-mocap-index-text.txt

Use the index to build `data/mocap/cmu_catalog.json`. Do not hand-type the catalog.

## Candidate CMU groups (unverified)

| Basketball action | Candidate CMU recordings | Notes |
|---|---|---|
| Defensive slides, containment | 102_22-29, 78_24-31 | 102_22-29 were imported earlier as assets/court/defense_102_*.glb (re-check) |
| Running, stopping, turning | 102_01-10, 127_05, 127_13-20 | locomotion and transitions |
| Drives, spins, feints | 102_11-21, 78_13-23 | offensive footwork |
| Forward/backward dribble | 06_02-07 | ball handling |
| Sideways dribble | 06_08-09 | ball handling |
| Crossovers, direction change | 06_10-14 | low dribbles and crossovers |
| Shooting | 124_03, 124_05, 06_14-15 | jump shots |
| Layups | 124_06, 15_12 | 15_12 is mixed-action |
| Free throw | 124_04 | |
| Passing | 15_12 | a segment needs extraction |
| Other basketball movement | 86_14 | dribble and shoot |
| Guard, reach, swat references | 76_04-05, 79_88, 56_04, 56_06 | not basketball-specific steals |

Known gaps (no verified recording yet): steal attempts and recoveries, hands-up
closeouts and shot contests, box-outs and rebound contests, standing dribbles and
stationary pass/catch if existing clips do not yield usable segments, screens,
contact reactions, coordinated player interactions.

CMU hand and toe joints are noisy, and finger/thumb motion was not captured. Do not
treat hand-to-ball contact from CMU as accurate. Full-body motion and hand
interaction are separate problems. The registry must distinguish them.

## When no CMU clip exists: reference images

A local copy of the CMU index was at `%TEMP%\court_cmu_index.txt` (2,888 lines,
2026-11-20). Search it first. If no recording shows the action:

1. Find several photos or video stills of the real action (NCAA or NBA game
   photos; Wikimedia Commons and university archives for reusable licenses;
   the user can supply their own). Record each source URL and license.
2. Describe each reference joint by joint: shoulder, elbow, wrist, hip, knee,
   ankle (angle estimate and position relative to the body), and where the
   hands are relative to the ball and head. Name what the photo can't show.
3. Use those descriptions as the target poses for an authored clip (keyframes)
   or as bounded IK targets, and as the acceptance reference: put the render
   and the references side by side (Pillow) and compare joint by joint.
4. Mark the coverage entry `missing (image references)` with the reference
   list, so the next agent does not search again. Commit an image only if its
   license allows; otherwise keep the link.

Known for the shot contest (2026-11-20): no contest clip in the CMU index.
Closest candidates, not downloaded: 13_10, 13_12, 14_07-09 ("jump up to grab,
reach for"), 14_20 ("reach up"). References gathered: Springfield College #11
contesting (Digital Commonwealth, CC BY-SA:
https://www.digitalcommonwealth.org/search/commonwealth:ks65kz76j) and four
user-supplied NCAA photos (Arizona #35 hands up at the rim; Central Oklahoma
#20 arms up in a wide stance; two perimeter defenders with arms wide).

## What every animation record needs

- Source: file name (e.g. 102_27.bvh), original description, source path
- Properties: duration, root displacement, direction, loopability, foot contacts
- Game mapping: the gameplay state it serves (e.g. defense_lateral, steal_attempt)
- Integration: skeleton, rest-pose correction, retargeting, mirroring, blend rules, cut start/end frames
- Validation: imported? visually reviewed on the rendered mesh? correct in gameplay?

## Files the repo should have (not yet confirmed to exist)

- data/mocap/cmu_catalog.json: CMU index generated from the upstream list, not hand-written
- data/mocap/animation_coverage.json: source of truth. One entry per required basketball animation: game state name, candidate CMU IDs, selected clip and source path, local resource path, cut frames, loopability, contact timing, transition requirements, status, known issues, evidence paths
- docs/animation/PIPELINE.md: select, cut, retarget, import, blend, validate; handling of missing recordings

Check these exist before citing them. If they do not, say so and offer to create them.

## Standing assignment: build the catalog once

Do this as one inventory task, not one clip at a time. Do not change game balance,
character models, blending, or gameplay behavior during it.

1. **Index CMU.** Parse the full index into `cmu_catalog.json`. Keep subject IDs, clip IDs, descriptions and source paths. Verify file availability. Tag basketball-relevant candidates by movement: locomotion, defensive footwork, dribbling, passing, shooting, layups, steals, rebounds, jumping, contests, pivots, collisions, transitions. A text match is not a verified usable animation.
2. **Inventory the Godot game.** Read every animation resource, imported BVH/GLB, state machine, script and procedural pose function. For each gameplay animation record: source recording (if any), mocap vs procedural vs blend, exact trigger, retarget and root-motion config, visual validation status, and any missing, unused or duplicated clip. Preserve working imports and the rest-pose correction.
3. **Build the coverage registry** (`animation_coverage.json`) for every required basketball action. Explicitly mark actions with no convincing recording as `missing`.
4. **Preview and audit.** Provide a tool that makes preview videos or frame strips for shortlisted recordings, and an audit command reporting: implemented and validated animations; imported but unvalidated; imported but unused; procedural with no mocap source; gameplay actions with no animation; candidates awaiting review.
5. **Make it permanent.** Write `docs/animation/PIPELINE.md`, and point the project's agent instructions (AGENTS.md or equivalent) at this skill and the two JSON files.

Deliverable: a coverage report and a prioritized list of unresolved basketball animations.

Once this exists, a request like "make a steal animation" should answer: which recordings might work, which were tested, what the tests showed, whether the current animation is procedural or mocap, and the next action.

## Coverage statuses

unreviewed, candidate, imported, validated, rejected, missing. Do not mark an
animation validated because it imported or passed a smoke test. Validation means a
rendered look at the mesh in gameplay context.

## Audit questions to answer from code and assets

1. Which gameplay animations are implemented and validated?
2. Which imported recordings are unvalidated?
3. Which imported recordings are unused?
4. Which animations are procedural with no mocap source?
5. Which gameplay actions have no animation?
6. Which candidate recordings await review?

Extract these from the Godot code, animation resources, and the import files. Do not
ask the user to remember them.

## Rules for working in this repo

- Consult the catalog and coverage registry before searching CMU or changing animation code.
- Reuse validated clips where possible. Keep source provenance and retargeting settings.
- Update coverage when an animation is added, changed, or rejected.
- Report missing motions explicitly. Do not invent a procedural replacement silently.
- Judge final motion on rendered gameplay footage of the mesh, never on the CMU stick figure or joint numbers.
- Preserve existing rest-pose correction and working imports.
- Do not change game balance, character models, animation blending, or gameplay behavior during an inventory task.

## Known finding: defender idle stance (The U, feat/court-mocap-retarget)

The staggered, bent-knee idle stance comes from the `Idle` clip's leg pose. Turning off
the crouch modifier, the defensive stance flag (`pressure_stance`), and the
`GuardHold` arm blend does not change the measured leg angles. The `GuardHold`
clip is a held frame of the `SlideR` shuffle. Fix the `Idle` clip or its source, not
the crouch or the arms.
