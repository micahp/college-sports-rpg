# The U

A mobile college-life RPG. You arrive at North Valley State with one life,
four years, and a walk-on evaluation on Saturday. Every choice closes a door.

**Current build:** Day One vertical slice — menu-driven, no 3D yet.
The simulation comes first; the campus is an interface to it.

## Run it

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open this folder in the Godot editor (`project.godot`).
3. Press F5. The main scene is `scenes/app/main.tscn`.

Mouse clicks emulate touch, so it plays fine on desktop while developing.

## Check it

```
godot --headless -s tests/run_checks.gd
```

Exits 0 when the time system, game state, and Day 1 content all pass.

## Project map

```
docs/       Frozen constraints, slice spec, data schemas, definition of done
data/       All game content as JSON (days, identities) — edit story here
scripts/
  core/     Autoload singletons: GameState, TimeSystem, ContentDB, SaveSystem
  ui/       day_flow.gd — the Day One screen flow
scenes/     main.tscn (UI is built in code)
tests/      Headless acceptance checks
```

Read `docs/GAME_CONSTRAINTS.md` before changing anything — those decisions are
frozen, and every AI-assisted task should cite it.

## What's next (in order)

1. Playtest Day 1 with five people; ship/no-ship signal is "I want to replay."
2. Days 2–6 as pure content in `data/days/`.
3. Day 7: the walk-on evaluation minigame (timing meter + stats).
4. Week recap screen — the shareable artifact.
5. Only then: the 3D quad.
