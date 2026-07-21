# Data Schemas

All game content lives in `data/` as JSON. Scripts load it through `ContentDB`.
Stat keys are always the six canonical strings:
`energy, academics, athleticism, basketball_skill, roommate_relationship, coach_interest`.

## Day file — `data/days/day_N.json`

```json
{
  "day": 1,
  "beats": [
    {
      "id": "morning_arrival",
      "period": "morning",
      "title": "Move-In Day",
      "text": "Narrative shown to the player.",
      "choices": [
        {
          "id": "help_unpack",
          "label": "Button label",
          "tags": ["social"],
          "duration_blocks": 1,
          "requirements": { "energy_min": 30 },
          "effects": { "energy": -10, "roommate_relationship": 12 },
          "reaction": "Text shown after the choice, before time advances."
        }
      ]
    }
  ]
}
```

Rules:
- `period` is one of `morning | afternoon | evening | night`, and beats must
  appear in that order.
- `effects` values are integer deltas; GameState clamps results to 0–100.
- `requirements` currently supports only `energy_min` (int). Unmet requirements
  disable the button and show the reason — they never hide it.
- `tags` feed the recap's "primary trait" (grind, social, scholar, rest).
- `duration_blocks` defaults to 1.

## Identities — `data/characters/identities.json`

```json
{
  "identities": [
    {
      "id": "workhorse",
      "name": "Workhorse",
      "blurb": "Shown under the button in character creation.",
      "effects": { "basketball_skill": 6, "athleticism": 4 },
      "tag": "grind"
    }
  ]
}
```

Identity `effects` are applied once, at character creation.

## Save file — `user://save_v1.json`

```json
{
  "version": 1,
  "time": { "day": 1, "period": 2 },
  "player": {
    "player_name": "Micah",
    "identity": "workhorse",
    "stats": { "energy": 65, "academics": 50, "...": 0 },
    "choice_history": [ { "beat": "morning_arrival", "choice": "help_unpack", "tags": ["social"] } ]
  },
  "flow": { "beat_index": 2, "content_day": 1 }
}
```

`period` is the TimeSystem enum int (0=Morning … 3=Night). `flow.content_day`
is the day whose beats `beat_index` points into — it can lag `time.day` by one,
because finishing the Night beat advances the clock while the recap still
belongs to the finished day. Bump `version` and the filename together on
breaking changes; old saves are discarded, not migrated, during the MVP.
