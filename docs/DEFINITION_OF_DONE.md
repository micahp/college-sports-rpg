# Definition of Done — Spatial Day One Slice

Hard rejection criteria (any true = build fails): gameplay is primarily text
and buttons; locations are menu options; no controllable visible player; no
visible map; no collision; NPCs exist only inside text boxes; the day can't be
completed start to recap; save/continue broken; mobile input missing.

## Milestone 1 — World (accepted 2026-07-21)
- [x] Player sprite visible in a campus courtyard, camera follows
- [x] WASD/arrow movement and visible virtual joystick both work
- [x] Collision: buildings, trees, benches, sign, world boundary
- [x] One NPC with proximity prompt and a closable conversation

## Milestone 2 — Conversations (implemented, awaiting checkpoint)
- [x] Three NPCs visible in the world: Jordan, Dee Alvarez, Coach Delgado
- [x] Prompt appears in range, disappears out of range
- [x] TALK button only visible when someone is in range; hidden during dialogue
- [x] Each conversation: name shown, 2–3 choices, immediate stat changes with
      deltas spelled out in the reaction
- [x] Choices are one-time; repeat visits get a repeat line and change nothing
- [x] Touch devices never see keyboard hints ([E] etc.)
- [x] `tests/campus_autoplay.tscn` passes headless (60+ input-driven checks)

## Milestone 3 — Places and time
- [ ] Dorm, classroom, gym interiors load through their doors and back
- [ ] Time advances only on completed activities; HUD updates
- [ ] Afternoon lock: entering class or gym consumes the period, other becomes
      unavailable
- [ ] Title screen: New Game works, Continue disabled without a save

## Milestone 4 — The full day
- [ ] Complete morning→night day, every interaction functional
- [ ] Day recap: choices made, stats, emerging identity, Continue button
- [ ] Autosave after meaningful actions; relaunch resumes correctly
- [ ] New Game resets all progress
- [ ] No interaction traps the player; no dead buttons; no TODO text;
      no uncaught runtime errors

## Feel (playtest with 5 people, after M4)
- [ ] They understood what to do without instructions
- [ ] They can name the choice that felt hardest
- [ ] They wanted to replay with different choices — the ship/no-ship signal
