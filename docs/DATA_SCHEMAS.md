# Data Schemas

All game content lives in `data/` as JSON and loads through `ContentDB`.
`tests/run_checks.gd` validates every file (`ContentDB.validate_week_content`).
Stat keys are always the six canonical strings:
`energy, academics, athleticism, basketball_skill, roommate_relationship, coach_interest`.

Days are 1–7 (1 = move-in Sunday, 7 = Saturday evaluation). Periods are
`morning | afternoon | evening | night`.

## Choices (shared by events and activities)

```json
{
  "id": "join_conditioning",
  "label": "Button label",
  "tags": ["grind"],
  "duration_blocks": 1,
  "periods": ["evening"],
  "days": [3],
  "requirements": { "energy_min": 20 },
  "set_flags": ["did_conditioning"],
  "effects": { "coach_interest": 9, "energy": -22 },
  "minigame": "shootaround",
  "check": { "stat": "academics", "min": 62, "pass": {...}, "fail": {...} },
  "reaction": "Shown after picking, with the stat changes as chips."
}
```

- `effects` are integer deltas, clamped to 0–100. Positive gains to
  academics, athleticism and basketball_skill shrink as the stat rises
  (`GameState.scaled_gain`); the UI always shows the change actually applied.
- `duration_blocks` — periods consumed. Default 0 in conversations (talking
  is free), 1 for activities. A night choice ends the day (recap → wake up in 214).
- `periods` / `days` — when the option is offered (omit = always).
- `requirements` — `energy_min`, `stat_min {stat: n}`, `flag`, `not_flag`.
  Unmet requirements disable the button and say why; a `not_flag` that is
  already set hides the option (one-time actions).
- `set_flags` — story switches (e.g. `signed_up`, `promised_match`, `quiz_failed`).
- `minigame` — `shootaround`, `showcase` or `tryout`; the result adds bonus
  stat changes (`Game.minigame_bonus`).
- `check` — a stat test; the `pass`/`fail` branch supplies effects,
  flags and reaction.
- `tags` (grind, social, scholar, rest) decide the ending's "kind of week".

## Story events — `data/story/events.json`

```json
{
  "events": [{
    "id": "coach_signup", "npc": "coach", "location": "campus", "spot": "rec_steps",
    "day": 1, "periods": ["evening"],
    "requires": { "not_flag": "signed_up" },
    "objective": "HUD objective + arrow while this is pending (optional)",
    "lines": ["Shown one at a time"], "choices": [ ... ],
    "repeat_line": "Said on later visits in the same period"
  }],
  "ambient": [{ "npc": "jordan", "location": "dorm", "spot": "jordan",
    "days": [1,2,3], "periods": ["night"], "lines": ["Rotating chatter"] }]
}
```

An event is live when its day, period and `requires` match; it's done once
any of its choices is picked (recorded in `choice_history` under the event id).
Live events claim their NPC; ambient entries fill in otherwise. An event with
`"tryout": true` starts the evaluation; `"spectator": true` ends the week in
the bleachers.

## Activity spots — `data/world/activities.json`

```json
{ "spots": [{ "id": "gym_court", "location": "gym", "spot": "court",
  "prompt": "SHOOT", "title": "Card title", "text": "Card description",
  "choices": [ ... ] }] }
```

A spot only appears when at least one of its choices is offered now.

## Locations and markers

Locations are `campus`, `dorm`, `classroom`, `gym` (`Game.SCENES`). Each
scene has `Markers/`: `arrive_<key>` spawn points, `spot_<id>` (where NPCs
stand / activities happen, -Z = facing), `door_<location>` exits, and in the
gym `hoop` + `shot_1..3`, `shot_ft`.

## NPCs, looks, identities, endings

- `data/world/npcs.json` — `{npc_id: {name, role, model, skin, shirt, pants, hair}}`.
  `model` is a key of `CharacterAppearance.MODELS`; skin is light/tan/brown/deep.
- `data/characters/looks.json` — the player's appearance presets (same fields).
- `data/characters/identities.json` — `{id, name, blurb, effects, tag}`;
  effects apply once at character creation.
- `data/story/endings.json` — scoring weights and thresholds, the five
  outcome texts, and epilogue tiers.

## Save file — `user://save_v2.json`

```json
{
  "version": 2,
  "time": { "day": 3, "period": 1 },
  "player": { "player_name": "...", "identity": "...", "look": "...",
    "stats": {...}, "choice_history": [...], "flags": {...},
    "day_start_stats": {...}, "tryout": {} },
  "flow": { "location": "gym", "arrival": "door" }
}
```

Saved after every choice, period change and door. Finishing the week deletes
it. Bump `version` and the filename together on breaking changes; old saves
are ignored, not migrated.
