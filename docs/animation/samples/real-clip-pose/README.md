# Real-clip 2D pose: sample and noise report (2026-11-23)

This is a sample of the pose pass run over the whole basketball reference library. The library has 201 real-footage clips across 33 actions (see `../../BASKETBALL_LIBRARY.md`). It's here so agents can look at how usable, and how noisy, raw 2D pose from broadcast footage is before anything is retargeted onto The U's rig.

**The footage itself is not committed.** This repo is public, and the library policy is links and timestamps only. Everything here is drawn from the stored keypoints.

## Files

- **`pose_skeleton_sample.mp4`** (36 s, 960x540)
  - 3 s each of free_throw, jump_shot, layup, dunk, crossover, behind_back, spin_move, block, rebound_defensive and outlet_pass.
  - Then the outlet_pass clip again at half speed.
  - It shows exactly what the tracker stored:
    - the 3 largest people per frame (cyan = largest, magenta = 2nd, green = 3rd);
    - bones only where both joints have confidence > 0.4;
    - grey dots for low-confidence joints;
    - each person's track id above them.
- **`booker_0000_jump_shot_pose.json`** and **`outlet_pass_G2LZwYgZMZo_147_pose.json`**: two raw outputs, one fairly clean and one noisy.
  - Format: `{source, fps, keypoints: "COCO-17 [x,y,conf]", frames: [{frame, t, people: [{id, box:[x1,y1,x2,y2], kp:[[x,y,conf] x17]}]}]}`.
  - Pixel coordinates are in the source video's frame. `people` is sorted by box area, largest first.

## How it was made

- `tools/reference/batch_pose.py`: Ultralytics YOLO11s-pose plus ByteTrack (`persist=True`, conf 0.3), on CPU. Clips above 45 fps are halved.
- `tools/reference/noise_stats.py`: the table below.
- `tools/reference/skeleton_reel.py`: the video. It renders from the JSONs, with no footage.

The paths in these scripts point at the local library (`E:/motion-reference/basketball/clips/<action>/`). The clips are not in the repo.

## Noise, measured on all 201 clips

"Main player" means the largest box in each frame. These columns are measured on the main player:
- **id switch**: share of frames where the main player's track id changes from the previous frame.
- **wrist jitter**: median frame-to-frame wrist movement, as a % of box height.
- **low-conf**: share of keypoints with confidence < 0.4.
- **no detection**: share of frames where no one is detected.

| action | clips | frames | id switch | wrist jitter (% body ht/frame) | low-conf keypoints | no detection |
|---|---|---|---|---|---|---|
| behind_back | 8 | 1095 | 17.4% | 5.5 | 18% | 2% |
| between_legs | 8 | 750 | 5.8% | 4.9 | 33% | 11% |
| block | 9 | 1324 | 7.1% | 4.1 | 26% | 2% |
| box_out | 2 | 672 | 11.3% | 3.1 | 35% | 12% |
| catch | 2 | 840 | 0.4% | 2.7 | 54% | 7% |
| celebration | 3 | 1560 | 3.9% | 2.1 | 46% | 0% |
| closeout | 8 | 790 | 7.2% | 2.5 | 18% | 15% |
| contest | 1 | 300 | 9.1% | 2.7 | 19% | 12% |
| crossover | 4 | 1680 | 7.2% | 4.3 | 21% | 4% |
| defensive_stance | 3 | 1440 | 6.0% | 2.8 | 39% | 14% |
| dribble_run | 1 | 840 | 1.1% | 1.5 | 26% | 0% |
| dribble_stationary | 3 | 1380 | 2.3% | 3.2 | 52% | 19% |
| dunk | 13 | 3646 | 9.7% | 5.8 | 30% | 3% |
| fadeaway | 8 | 917 | 10.7% | 4.3 | 27% | 10% |
| floater | 8 | 1131 | 11.1% | 4.2 | 21% | 5% |
| free_throw | 1 | 720 | 0.1% | 1.0 | 33% | 1% |
| high_five | 1 | 720 | 1.0% | 1.1 | 30% | 0% |
| hook_shot | 8 | 1083 | 7.9% | 6.5 | 37% | 18% |
| inbound | 8 | 852 | 8.5% | 3.3 | 25% | 2% |
| jump_shot | 29 | 8280 | 10.1% | 3.8 | 25% | 7% |
| jump_stop | 8 | 858 | 12.3% | 5.6 | 27% | 0% |
| layup | 19 | 4080 | 13.2% | 3.9 | 22% | 3% |
| loose_ball_dive | 8 | 1137 | 16.7% | 6.2 | 19% | 3% |
| outlet_pass | 8 | 992 | 20.5% | 6.0 | 19% | 7% |
| post_defense | 1 | 480 | 3.9% | 3.9 | 48% | 12% |
| post_up | 3 | 1530 | 9.2% | 2.3 | 23% | 8% |
| pull_up | 5 | 1440 | 13.4% | 5.1 | 19% | 5% |
| putback | 3 | 348 | 7.7% | 3.6 | 22% | 1% |
| rebound_defensive | 3 | 343 | 11.1% | 3.2 | 24% | 0% |
| rebound_offensive | 1 | 108 | 20.6% | 5.9 | 20% | 0% |
| spin_move | 9 | 1646 | 11.6% | 4.7 | 28% | 1% |
| step_back | 4 | 1410 | 8.1% | 3.8 | 23% | 4% |
| triple_threat_jab | 1 | 360 | 3.7% | 1.8 | 39% | 1% |

## What the noise is (from the sample video and the frame reads)

- **Identity.** Track ids drop to `-1` (detected but not tracked) or change mid-clip.
  - The "largest box" also changes hands when players cross, so the main-player stats mix real tracker switches with the main player simply changing.
  - Compilation clips also contain camera cuts. Every cut starts a new track.
  - Earlier, a Westbrook rebound clip needed manual relinking (nearest box) to keep one player.
- **Dropouts.** There are whole frames with nobody detected (the blank frames in the half-speed outlet pass), and limbs vanish when their confidence dips below 0.4.
- **Jitter.** Wrists move 3-6% of body height per frame even on slow actions. Free throw and high five, where the camera and player are steady, sit near 1%. That 1% is roughly the floor.
- **Occlusion.** Catch, dribble_stationary, celebration and post_defense have 45-55% low-confidence joints. Hands and ball are hidden behind bodies.
- **2D only.** There's no depth. Broadcast angles and zoom change the apparent limb lengths.

## Open questions for discussion

1. **Cleanup:** fix identity first (relink on box overlap and per-player appearance), then smooth (One Euro, Savitzky-Golay), or lift straight to 3D (MotionBERT, VideoPose3D, WHAM), which handles some of the jitter?
2. **Thin actions:** where should more clean footage come from? post_defense, rebound_offensive, triple_threat_jab and contest have one clip each.
3. **Use:** is 2D pose good enough to judge timing and contact (release frame, plant frame) against The U's animations, even if it's too noisy to drive the rig directly?
