# Campus student rig: specification

What the court player's skeleton is, as measured by `tests/rig/skeleton_checks.tscn`
(gate 1 of [RIG_CERTIFICATION.md](RIG_CERTIFICATION.md)). Source:
`assets/court/students/Male_Casual.fbx`, imported with the bone map
`assets/court/bonemap_student.tres` and the retarget rest fixer
(`fix_silhouette` on, see "Known defects"). Built by
`CourtPlayerModel.build_student`, scaled by `court_actor._normalise_height`.
Numbers in centimetres are at game scale (0.3416 m per skeleton unit; the
mesh stands 1.774 m).

## Spaces

| | |
|---|---|
| Skeleton space | +Y up, +Z the body's front (toes, thumbs), +X the body's **left** |
| World | the skeleton's `global_transform`; the actor's facing is `_model.rotation.y` |
| Body frame (game code) | `facing()` = +Z rotated by the model's yaw, `right()` = facing x up (= skeleton -X) |

## Hierarchy (humanoid bones)

```
Bone (root)
 +- Hips            body controller, sits 6.8 cm BELOW the pelvis joint; no skin of its own
 |   +- Spine       the pelvis/waist (skin: lower abdomen and the top of the shorts)
 |   |   +- Chest - UpperChest
 |   |                  +- Neck - Head
 |   |                  +- LeftShoulder - LeftUpperArm - LeftLowerArm - LeftHand - fingers, thumb
 |   |                  +- RightShoulder - ... (mirror)
 |   +- LeftUpperLeg - LeftLowerLeg - LeftFoot      (the legs hang off Hips, not Spine)
 |   +- RightUpperLeg - RightLowerLeg - RightFoot
 +- Foot.L, Foot.R  shoe control bones (the shoe's skin); placed every frame by student_feet.gd
 +- PoleTarget.L/R  unused
```

- `LeftFoot`/`RightFoot` are the end of the shin, with no skin; the shoe is
  skinned to `Foot.L`/`Foot.R`, which hang off the root, not the leg.
- There are no toe bones. `foot_floor.gd` looks for `LeftToes`/`RightToes` and
  so does nothing on this rig.
- `build_student` renames the skin's `Hips` bind to `Spine`, so waist vertices
  follow the pelvis, not the controller.

## Rest transforms and scale

Every bone's rest is unit scale and right-handed. No clip in the library writes
a scale key, and no correction scales a body bone (gate 5). `student_feet`
scales the shoe controls by 1.14 (`SHOE_SCALE`), which is declared. The rest
pose is a T-pose with horizontal arms and straight vertical legs. A straight leg
has no bend plane, so leg IK needs a pole.

## Bone axes

| Bone | +Y | Other axes at rest |
|---|---|---|
| Trunk (Spine..Head) | world up | identity, world-aligned. The spine curves forward 11 deg at Chest and Neck; the axes don't follow it. |
| Upper arm, forearm, hand | toward the child joint | L upper arm: X back, Z down. L forearm: X down, Z **front**. L hand: X back, Z down (the palm normal). |
| Thigh | down the leg | X = body right, Z front |
| Shin | down the leg | X = body left, Z **back** (rolled 180 deg from the thigh about the bone) |
| LeftFoot / RightFoot | forward along the foot | Z up |

**Mirror convention:** each right bone is the left bone mirrored across the
midplane with local X negated. The same motion on both sides is therefore the
same angle about local X, and the opposite angle about local Y or Z.

## Joint hinges and IK pole axes

| Joint | Flexion axis | Positive flexion | Tip axis (IK pole direction) |
|---|---|---|---|
| Elbow | forearm local +X | folds the hand to the front | forearm **-Z** points at the elbow tip (back) |
| Knee | shin local +X | folds the foot back | shin **-Z** points at the knee cap (front) |

`court_actor.POLE_AXIS_STUDENT` is `SECONDARY_DIRECTION_MINUS_Z`, which matches.
The old player rig keeps +Z (`POLE_AXIS`). A leg TwoBoneIK3D on this rig needs
MINUS_Z on the shin. The rest forearm sits about 7 deg off the shoulder-elbow
line, so twisting about the forearm's local +Y is not pure pronation; pronation
is about the elbow-wrist line.

## Proportions (share of stature, against Winter / Drillis & Contini)

| | rig | human |
|---|---|---|
| shoulder height | 0.760 | 0.818 |
| hip joint height | **0.422** | 0.530 |
| knee height | 0.262 | 0.285 |
| ankle joint height | **0.013** | 0.039 |
| upper arm | **0.137** | 0.186 |
| forearm | 0.159 | 0.146 |
| thigh | **0.160** | 0.245 |
| shin | 0.249 | 0.246 |

The hip and thigh figures come from the import defect below: the skin was bound
with the hip joint 11.3 cm higher. The upper arm is short in the mesh itself.

## Known defects (gate 1)

1. **Rest pose is not the skin's bind pose.** The retarget rest fixer
   (`fix_silhouette`) moved the bones after the skin was bound, and the skin
   binds were not updated. Joints were bound at these offsets from their rest
   (x left, y up, z front):

   | Joint | Bind offset from rest (cm) |
   |---|---|
   | hip and knee | (0, +11.3, -6.5) and (0, +11.4, -7.9) |
   | shoulder (upper arm) | (∓3.2, +7.6, +1.5) |
   | elbow | (∓3.4, +5.9, -1.0) |
   | shoe control | (0, +14.5, -9.0) |

   At rest, the bones sharing a vertex disagree by up to 13 cm at the hips,
   26 cm across the shoulders and 15 cm at the shoes. The same FBX imported
   with `fix_silhouette` off has rest equal to bind everywhere (0.0 cm). Visual:
   `tests/rig/bind_compare.tscn`.
2. **Left upper arm is 2.1 cm longer than the right** (25.4 vs 23.3 cm). The
   left elbow sits 3.6 cm from where the skin bends; the right sits 1.0 cm. The
   arm mesh is symmetric to within 1.2 cm.
3. **No toe bones**, so `foot_floor` never acts.
4. **The ankle joint is at the sole** (2.4 cm high, against about 7 cm). The
   shoe pivots on its control bone, not at the ankle.
