# The U — MVP Constraints

These decisions are frozen. Do not reinterpret them while implementing features.
If a task appears to require breaking one of these, stop and flag it instead.

## Platform
- Godot 4.x
- Typed GDScript only (no C#)
- Android first, iOS later
- Landscape orientation
- Offline, single-player
- Touch input required; mouse input supported for development

## Presentation (revised 2026-07-21 — spatial plan is accepted and final)
- Top-down 2D spatial campus; the player controls a visible character sprite
  moving through a visible world. Menu/text-driven gameplay is rejected.
- Camera follows the player; no free rotation
- Direct movement: WASD/arrows on keyboard, virtual joystick on touch
- Interactions happen by physically approaching NPCs and entrances
- Placeholder art is generated in code (no imported assets yet)
- Prompts and hints must be touch-aware: never show keyboard keys on touch devices

## World
- No seamless open world
- One outdoor campus hub (the quad), ~20–30 seconds to cross
- Interiors load as separate scenes through building doors
- Player collides with buildings, trees, benches, and world boundaries
- Maximum 12 active NPCs per scene
- NPCs do not need autonomous full-day schedules
- Walking never advances time; completed activities do

## Simulation
- Four time blocks per day: Morning, Afternoon, Evening, Night
- Time advances only when an activity completes — never in real time
- Six primary player stats, each 0–100:
  energy, academics, athleticism, basketball_skill, roommate_relationship, coach_interest
- All activities, story beats, and events are data-driven (JSON in `data/`)
- The 3D world is an interface to the simulation; it never contains the simulation

## MVP scope
- Seven in-game days (vertical slice: Day 1 only)
- One fictional university: North Valley State
- One athletic path: basketball
- One tryout minigame (timing-based, not 5-on-5)
- Three meaningful NPC relationships
- One ending recap screen
- No multiplayer, no monetization, no procedural generation
- No real school names, logos, or likenesses

## LLM task rules
- One bounded module per task, with an explicit ALLOWED FILES list
- Never modify `project.godot`, imported assets, or unrelated systems in a feature task
- New mechanics are added as data first; code only when the schema can't express it
- Every system ships with acceptance tests in `tests/`
