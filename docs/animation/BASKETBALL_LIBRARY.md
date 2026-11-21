# Basketball motion library: map (2026-11-21)

Every basketball action a player needs, what plays it in The U today, which
recordings could supply it, and which real footage shows it. This is the
basketball part of the shared athlete motion library (football next, same
format): one row per action, with the same action names used by The U's court
code, the gridiron-physics basketball action library
(`feat/basketball-action-library`, `web/basketball/library.js`) and the
reference registry.

- **References:** `data/animation/basketball_references.json` (sources, segments,
  status). Links and timestamps only: the footage is not committed,
  redistributed or embedded. Local copies live outside the repo in
  `C:/Users/micah/Videos/motion-reference/basketball/` (`sources/`, `clips/<action>/`,
  `sheets/` overviews).
- **Tools:** `tools/reference/time_index.py` (labeled overview of a long video,
  for tagging), `tools/reference/cut_refs.py` (cuts registry segments into
  `clips/<action>/`, optional consecutive-frame sheets).
- **Reference status:** *frame-read* = consecutive frames read (the watch-video
  method); *tagged* = spotted on a 4-5 s overview, window approximate, action not
  yet confirmed. Slow-motion replays (Phantom) give poses and order, **not
  timing**; timing needs real-speed footage.
- **Motion status** (catalog skill): missing, candidate, imported, validated,
  rejected. *validated* means judged on the rendered mesh in the game; none is
  marked validated here yet, because no row has a rendered side-by-side with its
  reference.

## How a row moves forward

1. Tag references (overview) and frame-read the best two or three: one at
   real speed for timing, one close (Phantom) for poses.
2. Write the phase spec from them (REBOUND_BRIEF.md is the model).
3. Pick the motion source per body part (clip, procedural, IK) and the owner
   per joint (OWNERSHIP.md).
4. Render it next to the reference; update the row.

## Locomotion and footwork

| Action | In The U today (source / owner) | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| idle_ready | `Idle` (UAL, retargeted on rig/retarget) | | timeout_huddle (dead ball) | imported | live-ball ready stance reference |
| walk | `Walk` (UAL) | | timeout_huddle | imported | |
| jog | `Jog` (UAL Jog_Fwd), `JogM` (CMU 16_36) | 16_35, 02_03 | Booker reel (real speed) | imported | |
| run | `Run` (CMU 09_01) | 09_02 | Booker reel | imported | |
| sprint | `Sprint` (UAL) | 127_* | dribble_fullcourt_giannis (with ball) | imported | |
| start_accel, stop_decel | gait controller (phase-matched crossfade) | 102_01-10 | none yet | candidate | real-speed stops: tag in Booker reel |
| cut_turn | gait controller, facing turn capped 720 deg/s | 102_01-10, 127_13-20 | none yet | candidate | |
| backpedal | `Backpedal` (CMU 06_06) | | none yet | imported | |
| defensive_stance | `GuardHold` (held frame of SlideR) over Idle | 102_22-29 | stance_okc_hou, stance_rockets, stance_smart (tagged) | imported | frame-read the stances; GuardHold is a slide frame, not a stance |
| defensive_slide | `SlideL`/`SlideR` (CMU 102_24-28) | 102_22-29, 78_24-31 | slide_basics (drill, 360p) | imported | real-game slide reference |
| closeout | none | | none yet | missing | |
| jump_stop | none | | jump_stop_pivot_pass (Jr. NBA drill) | missing | |
| pivot | none (gather turns the root) | | forward_pivot, jump_stop_pivot_pass (Jr. NBA) | missing | needed by the rebound follow-up and post play |

## Ball handling

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| dribble_stationary | ball path `dribble_ball.json` + arm over Idle | 06_02-07 | dribble_iso_derozan, dribble_barrett, dribble_simmons, dribble_trae_low | candidate | frame-read one close dribble for hand-ball timing |
| dribble_run | `DribbleRun` (CMU 06_02) | 06_02-07 | dribble_fullcourt_giannis, Booker reel | imported | |
| crossover | procedural `_update_crossover` | 06_10-14 | dribble_iso_kyrie_lebron, dribble_curry_hou | candidate | |
| triple_threat_jab | none | | dribble_jab_lebron_tor | missing | |
| spin_move | none | 102_11-21, 78_13-23 | spin_siakam (tagged) | missing | |
| step_back | none | | stepback_harden_min, stepback_harden_early | missing | |
| behind_back, between_legs, hesitation | none | 06_10-14 | none yet | missing | |

## Passing and catching

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| chest_pass | `Pass` (UAL Push) | 15_12 (a push, not a confirmed chest pass) | pass_usab (USA Basketball) | imported | split pass_usab per pass type |
| bounce_pass, overhead_pass, one_hand_pass | none in The U (authored in the gridiron library) | | pass_usab | missing | |
| outlet_pass | none | | REBOUND_BRIEF (coaching text only) | missing | |
| catch | procedural palm IK | | catch_shoot_carmelo, catch_kuzma | candidate | |

## Shooting and finishing

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| jump_shot | `JumpShot` (CMU 124_05), arms rewritten by four layers (clip_fidelity) | 124_03, 124_05, 06_14-15 | shot_kawhi_tor, shot_tatum_*, shot_mitchell, shot_beal_iso, shot_george_lac, shot_buzzer_lakers, booker_shots_real (real speed) | imported | real-speed timing from Booker reel |
| pull_up | `JumpShot` off the dribble | | shot_lillard, Booker reel | candidate | |
| free_throw | none (uses `JumpShot`?) | 124_04 | ft_lebron (frame-checked: set and routine at the line) | missing | |
| layup | `Layup` (CMU 124_06) | 124_06, 15_12 | layup_kyrie_bos, layup_mitchell, layup_lebron_por | imported | |
| floater, fadeaway, hook | none in The U (authored in the gridiron library) | | none yet | missing | |
| dunk | none | | dunk_westbrook, dunk_lebron_nyk, dunk_lebron_lal, dunk_zion, dunk_morant, dunk_collins | missing | |
| pump_fake | none | | reb_off_sabonis_pump | missing | |

## Defence

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| contest | procedural arm raise (contest_lift), checked by contest_pose_check | 13_10, 13_12, 14_07-09, 14_20 (13_10/13_12/14_07 rejected as jumps) | contest_lebron_por (tagged); stills listed in AGENTS.md | candidate | joint-alignment contest regression open on rig/retarget |
| block | none | | block_mavs_bos (tagged) | missing | |
| steal_swipe | `SwipeCMU` (CMU 56_04) + procedural `_pose_swipe` | 76_04-05, 79_88, 56_04, 56_06 | none yet | imported | swipe_pose_checks exercises nothing (0 of 36) |
| post_defense | none | | post_def_tucker_durant | missing | |
| box_out | none (rebound has no box-out) | none in the index | reb_boxout_harwood_B (frame-read), boxout_ft_gsw_okc, film_room_box_outs | missing | two-player contact stage |

## Rebounding

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| rebound_defensive | procedural: root parabola, arm IK, palm-contact catch, chest-relative gather around the head | BallPlay-M take (standing, licence unchecked) | reb_def_westbrook + reb_def_westbrook_live_182 (slow + paired live), reb_def_tip_harwood_C (frame-read), reb_def_hinton_reel (tagged) | candidate | REBOUND_BRIEF.md: JumpShot window for legs and trunk; a defensive jump-and-land with feet in view |
| rebound_offensive | same controller | | reb_off_sabonis_pump | candidate | |
| putback | none (separate second jump, per the brief) | | reb_putback_harwood_A (measured), reb_putback_horford + reb_putback_horford_live (slow + paired live) | missing | ball stays high, no chest gather |
| tip | none | | reb_def_tip_harwood_C, anunoby_tip_in | missing | |

## Off-ball and team play

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| screen_set | procedural `_tick_screener` (root placement) | | none yet | candidate | |
| screen_use, off_ball_cut | gait only | | dribble_curry_hou (off-ball movement, tagged) | candidate | |
| post_up | none | | post_embiid, post_davis | missing | |
| inbound | none | | none yet | missing | |

## Reactions and dead ball

| Action | In The U today | Mocap | References | Motion status | Next |
|---|---|---|---|---|---|
| celebration | `Clap` (UAL Interact) | | celebrate_lillard, celebrate_kings_bench, celebrate_doncic | imported | |
| high_five | none | | high_five_tatum | missing | |
| dead_ball_idle | `Idle`, `Walk` | | timeout_huddle | imported | |
| foul_reaction, loose_ball_dive, get_up | none | | none yet | missing | |

## Sources indexed so far

| Source | Indexed | Notes |
|---|---|---|
| NBA Phantom compilation (38 min, slow-mo, close) | whole video, one labeled frame per 4 s (`sheets/phantom_8DEJ1rDp8MM`) | most of the tagged rows |
| Booker 2025-26 top plays (20 min, real speed) | whole video, one frame per 5 s; plays not yet tagged one by one | best real-speed source for shot and drive timing |
| Westbrook Phantom board + 2021 live broadcast, Horford putback + Game 5 live highlights | paired live clips frame-read (`reb_def_westbrook_live_182`, `reb_putback_horford_live`) | timing and pose comparison for rebound refs D-E |
| Sabonis reel, Harwood HS (CC BY) | frame-read where listed | rebound refs A-F |
| Hinton (NCAA) two reels, Rodman 21 boards, Film Room box-outs, Anunoby tip-in | not yet indexed in detail | rebound and box-out candidates |
| USA Basketball passing, Jr. NBA pivot and jump-stop drills, defensive slide drill | not yet split | fundamentals at real speed |

## Gaps that need new footage

closeout, behind-the-back and between-the-legs dribbles, hook shot, floater,
fadeaway, inbound, foul reaction, loose-ball dive, getting up, outlet pass,
a defensive jump-and-land rebound with the feet in view, a real-game defensive
slide at full speed.
