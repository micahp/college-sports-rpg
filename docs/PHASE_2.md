# The U: Phase 2 (the season)

Phase 1 (`GAME_CONSTRAINTS.md`, `VERTICAL_SLICE.md`) is the tryout week and is
done. Phase 2 adds what happens after you walk on. Phase 1 docs stay as the
record of that week; this file is the source of truth for Phase 2.

## Scope
1. **Playable court.** Real game moments you control (this doc, below).
2. **Regular season.** 12 weekly games after you make the roster. Each week has
   slots (practice, study, social, rest); your choices set your rating going in.
3. **Home base.** A board you check between games: schedule, record, standing,
   stats, next game. You never walk to away games.
4. **Love interest.** One fixed NPC, built like Jordan (data-driven beats,
   relationship stat), ending in a date.

Out of scope this phase: playoffs and March Madness (own task), recruiting,
injuries, multiple seasons, player-controlled defense.

## Court design (decided from NBA 2K research)
- **Full-court arena, half-court offense.** Both baskets, midcourt line,
  stands. You play North Valley State's possessions live; the opponent's
  possessions resolve as a banner (score or stop).
- **Fast breaks.** A stop can turn into a break: you start at half court
  with one or two defenders back and the rest trailing, short shot clock.
- **Game moments, not full games.** A moment is a stretch of real game time
  (quarter, clock, score, a coach's note). The clock and score keep moving;
  the rest of the game is simulated around your stretches.
- **Camera: 2K "Turbo"-style.** Behind your player, never flips, shifts a
  little with your position. There is no camera control.
- **Controls:** one stick (screen-relative), SHOOT (hold, release in the
  gold), PASS (aims where you push the stick; gold ring shows the target).
  If dribble moves are added later they are body-relative ("Absolute").
- **Shooting:** 2K15 idea. Shot quality scales the timing window: open and
  at the rim is wide, contested and from three is narrow. Defenders close
  out while you hold, so a slow release gets contested.
- **Defense AI:** man-to-man, sag toward the ball, one helper when you get
  into the paint, closeouts on the shooter, passing lanes can be jumped,
  dribbling straight into your man risks a strip.
- **Getting open (researched from how the modern game works):** 5-out
  spacing with teammates relocating away from the ball; pick-and-roll on
  call (PICK / C) or automatically if you stall, with the opponent's
  coverage deciding the read (drop: pull up or hit the popper; hedge: hit
  the roller; switch: attack the slower big); help defense leaves a
  shooter open on drives; denied teammates cut backdoor.
- **Visible ball security:** a procedural IK upper body (`arm_pose.gd`):
  dribble hand on the ball, arm bar, defensive stance with active hands,
  hands-up contests, swipes. Steals are real swipes (steal, deflection into
  a loose-ball scramble, whiff that leaves him off balance, reach-in foul).
  Running into a defender is a bump, never a turnover. Auto crossovers keep
  the ball away from the defender's side.
- **Planned on top:** a Hot Hand meter (2K19 Takeover idea) filled by your
  week's choices, and a few badges (2K15 idea) earned through practice and
  relationships. Avoid grind or pay-to-skip progression (2K19 critique).

## Standards this follows (and where they come from)
- **Controls:** shown in the pause menu, not on the buttons (2K: Options >
  Controller). Keyboard, controller and touch all go through input actions.
  Controller layout is 2K's: X/Square shoot, A/Cross pass, LB/L1 pick,
  RT/R2 sprint, Start pause.
- **Pause:** the engine's `SceneTree.paused` with a pause menu scene set to
  process while paused (Godot docs, "Pausing games and process mode").
- **Animation:** an `AnimationTree` (blend space for Idle/Walk/Run by speed,
  one-shot for jumps) and the engine's `TwoBoneIK3D` for hands (Godot 4.6+).
  No hand-written IK solver.
- **Shooting:** 2K's rule. Release inside the window and it goes in; the
  contest narrows the window; just outside the window falls back to
  real-life percentages. Contest levels are the NBA tracking buckets
  (closest defender under 2 ft, 2-4, 4-6, 6+).
- **Layups:** shoot while driving close to the rim; sprinting with an open
  lane is a dunk (2K). Division I teams make about 55% of layups
  (Hoop-Math, via AP 2015); the per-contest split is an estimate.
- **Court players and clips:** court players are the Quaternius Universal
  Base Characters (CC0, standard humanoid skeleton) with a tinted uniform
  (`court_player_model.gd`). Locomotion is the Quaternius Universal
  Animation Library (CC0, same skeleton, no retargeting). Basketball
  motion is real mocap from the CMU Graphics Lab database (no usage
  restrictions): walking dribble, defensive slides both ways, jump shot,
  layup. `tools/court_assets/build.py` (Blender, headless) cuts, turns,
  in-places and loops the clips; Godot retargets them at import through the
  bone maps in `assets/court`. Campus characters are unchanged.
  **Build:** the model's base shape is a lean college build; a "Bulk"
  blend shape (0 to 1) adds muscle. The user's bulk comes from the
  athleticism stat (`court_game.gd` `user_bulk()`), so gym work shows on
  the body. The gym activity itself is a season-slot task, not built yet.
  Missing: a standing dribble, a sprint dribble, pass, steal and
  block clips (CMU subject 102 has more drives, feints and spins to cut).
- **Reality checks (how animation is judged):** every clip is compared
  with the original recording it came from, and every consecutive frame
  of a recording is read before anything is called fixed (the
  `watch-video` skill). Dribble: `tools/court_assets/bake_dribble.py`
  records where the real performer's hands were and when the ball left
  and returned; `tests/court_dribble_qa.tscn` plus
  `tools/court_assets/dribble_report.py` compare the game with it at five
  speeds (hand on ball 0.40 s, ball away 0.60 s, hand 0.77 m at release,
  1.03 m at the catch, scaled to the game's 1.81 m avatar). The ball's
  flight is solved in real time as projectile motion with one bounce. A
  mocap wrist target is used only for the ball handler; its IK pole follows
  the animated elbow. Gameplay hand targets (catch, screen, contest and
  swipe) still layer over the base animation through Godot's TwoBoneIK3D.
  This keeps backpedal and defender locomotion on their original retarget,
  since applying the mocap wrist fix to those clips distorted the arms. The
  dribble timing and hand heights now pass at five tested
  speeds. Still to check the same way: jump shot, layup, slides, backpedal,
  jog, run, pass, reach, contest.
- **Court audio:** `court_audio.gd` plays generated sounds
  (`tools/court_assets/make_audio.py`, nothing licensed): dribble and
  loose-ball bounces, net swish, rim, sneaker squeaks on cuts and screens,
  catch slap, whistle (fouls, out of bounds), buzzer (shot clock, end of
  the stretch), a crowd bed that gets louder late in close games, and a
  cheer on makes. They are synthesized placeholders; a recorded pack would
  sound better.
- **Still one big script:** `court_game.gd` (rules, ball, both AIs, HUD) has
  not been split into separate nodes yet.

## Files
- `scripts/court/pause_menu.gd`, `scenes/court/pause_menu.tscn`
- Test: `tests/court_checks.tscn` (forces each situation: input bindings,
  contest buckets, pause, pick, blow-by, layup)
- `scripts/court/court_game.gd`, `scripts/court/court_actor.gd`,
  `scenes/court/court_game.tscn`
- Test: `tests/court_proto.tscn` (auto-plays a stretch, checks the box score;
  `-- shots <dir>` saves screenshots)
- Preview: web build `index.html?court`, desktop `-- court`

## Court players are drawn sprites (2026-11-16)
The court uses no 3D player model, rig or mocap. `tools/court_sprites/draw.gd`
draws every frame from 2D shapes and hand-written poses (where the feet,
hands and hips are through each move), in 8 directions, into
`assets/court/sprites`. `scripts/court/court_sprite_actor.gd` shows them.
Sheets store part and shade, so one set serves every team and skin tone. The
dribbling hand and the ball share one bounce curve
(`scripts/court/court_dribble.gd`). To change how a move looks, edit its pose
in `draw.gd` and re-run it. The old rigged players remain at `?court3d`.

