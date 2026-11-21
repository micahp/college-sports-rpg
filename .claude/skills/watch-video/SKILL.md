---
name: watch-video
description: How to actually review a video, animation, screen recording or gameplay clip - by reading every consecutive frame in order, not a few sampled stills. Use this before saying anything about how something moves, looks in motion, animates, plays, transitions, bounces, slides, or whether a motion bug is fixed. Use it whenever a video or recording was just made or received (mp4, avi, mov, webm, gif, movie-writer output, a recorded test run), whenever the user asks "did you watch it", "how does it look", "is it fixed", or reports that motion looks wrong, and before telling the user a visual or animation change works. Also use it for image sequences rendered from Blender, Godot, Unity or a browser.
---

# Watch the video: read every frame, in order

A video is a stack of images. There is no video input, but every one of those images can be read. The failure this skill exists to prevent is sampling a handful of small frames spread across a clip, seeing that each pose looks plausible, and reporting that the motion is fine. Poses hide exactly what makes motion wrong: timing, rhythm, weight, a ball that floats, a foot that slides, a hand that carries instead of dribbles. Those only show between consecutive frames.

In the session this came from, a dribble was declared fixed three times from sparse stills. Reading 24 consecutive frames showed in one look that the player carried the ball from head height to his knee, that it rose to his shoulder, and that it fell in 3 frames but took 8 to come back up. The user had seen all of that in two seconds.

So: before making any claim about motion, look at the motion the only way available. Consecutive frames, large enough to read, covering the moment that matters.

## The procedure

1. **Find the moments that matter.** A whole clip at every frame is usually too much, so pick windows: the action the user complained about, each transition, each contact (foot plant, ball release, catch, bounce, collision), and the first and last half second. If you don't know where the problem is, make one coarse overview sheet first (see step 2 with `--step`), then go dense on the suspicious parts.

2. **Lay out consecutive frames.** Use the bundled script. It writes contact sheets where frames run left to right, top to bottom, with no gaps:

   ```bash
   python <skill-dir>/scripts/frame_sheets.py clip.mp4 out_dir --start 2.0 --duration 0.8
   ```

   Useful options:
   - `--start`, `--duration` (seconds): the window. Keep windows short (0.5 to 1.5 s) so every frame fits.
   - `--crop W:H:X:Y`: zoom on the subject. Do this. A full 1280x720 frame shrunk into a grid loses the feet, the hands and the ball. Crop to the thing being judged.
   - `--step N`: take every Nth frame. `--step 1` (default) is every frame. Only raise it for the overview pass, never for the check itself.
   - `--cols`, `--rows`: grid shape (default 8 x 3 = 24 frames per sheet). It writes as many sheets as the window needs.
   - `--cell-width`: width of each frame in the sheet (default 360). Keep cells at 300 px or more.

   It also works on a folder of numbered images: pass the folder and `--pattern "f_%04d.png"`.

3. **Read the sheets like a flipbook.** Go frame to frame and track one thing at a time across the row: where is the ball, where is the hand, where is each foot, where are the hips. Ask what changed since the previous frame and whether that change is the size and direction it should be. Count frames for durations (frames divided by fps): how long is the ball in the hand, how long in the air, how long is a foot planted.

4. **Turn motion into a picture when frames aren't enough.** Two things read well as stills:
   - **A graph over time.** Dump the numbers (ball height, hand height, foot height, speed) per frame and plot them on one chart. A path that floats, snaps or never reaches the floor is obvious as a curve.
   - **A trail.** Draw the object's whole path on one image.
   Prefer measuring from the source (the engine, the script that made the clip) over estimating from pixels.

5. **Say what you saw, with frame counts.** Report concretely: "in hand for 10 frames (0.33 s) from head height to knee", not "the dribble looks plausible". If something looks wrong, say what and where. If a window wasn't checked, say so.

## What to look for

- **Timing asymmetry**: something that falls fast and rises slow, or the reverse. Real motion under gravity is symmetric around a bounce apart from energy loss.
- **Holds and carries**: an object stuck to a hand or a pose held across many frames where it should release.
- **Contact**: does the foot or ball actually touch the surface in some frame? Fast objects can skip contact between frames; if no frame shows contact, it will look like bouncing off air.
- **Sliding**: a planted foot that changes position against the floor pattern from frame to frame. A fixed camera or floor markings make this visible; a camera that follows the subject hides it.
- **Pops**: one frame where a limb jumps far more than in the frames around it.
- **Range of motion**: how high and low a hand, ball or body actually goes compared with what the action should need.
- **Things that are layered from different sources**: arms from one clip over legs from another, an object added by formula over a recorded body. Seams show as parts moving out of step with each other.

## Honesty about the limit

Reading frames is not the same as watching. Smoothness, feel and anything subtle at full speed can still be missed, and the user's eyes remain the better judge. So:

- Never say "I watched it" about a clip. Say which frames were read and how many.
- Never report a motion problem as fixed on the strength of a few stills, a passing test, or a metric alone. Read the consecutive frames of the exact moment that was broken first.
- When the frames do look right, say that and still hand the clip to the user as the real check.
