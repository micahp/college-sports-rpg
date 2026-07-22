# Vertical Slice — Day One at North Valley State

One sentence: *A stylized 3D mobile college-life RPG where the player walks
their first day at a fictional university, and choices made face-to-face
affect academics, energy, relationships, and athletic opportunity.*

The original menu-driven slice was rejected on 2026-07-21: the spatial layer
is a required game mechanic, not presentation. The slice is now delivered in
verified milestones, each stopping for a user checkpoint before the next.

## Milestones

**M1 — World (DONE, audit passed).** Campus courtyard map, visible player,
camera follow, keyboard + virtual joystick movement, collision, one
interactable NPC with a linear conversation.

**M2 — Conversations (DONE, 2D; systems archived).** Three spatial NPCs —
Jordan Hayes (roommate), Dee Alvarez (orientation leader), Coach Delgado —
with interaction range, dialogue choices, immediate visible stat changes,
one-time choices with repeat lines, and touch-aware prompts. Built and
verified on the 2D layer; the data and systems carry into 3D at M3.

**M1.5 / M1.6 — Stylized 3D presentation (DONE).** The campus is rebuilt as an
editor-authored 3D scene: branded North Valley State courtyard, the Rec Center
hero building, six background students, art-directed lighting, ambient audio,
polished mobile UI, and a cinematic conversation two-shot. Postable
screenshot + 15-second clip without a prototype disclaimer.

**M3 — Places and time (next).** Rewire the M2 conversations and stats into
the 3D campus. Dorm/classroom/gym interiors behind real
doors, scene transitions, the four-period time system wired to activities,
afternoon activity locking (class OR gym), title screen with New Game /
Continue.

**M4 — The full day.** Complete morning→night sequence, day recap screen,
save/continue restoring mid-day state, full regression pass.

## Content sources
NPC conversations live in `data/dialogue/day1_npcs.json`; narrative and stat
effects are adapted from the original `data/days/day_1.json` beats, which
remain the source for M3's time-block activity structure.

## Definition of "this slice is done"
See DEFINITION_OF_DONE.md. The headline test: a playtester finishes Day 1 and
says "I want to try again and make different choices."
