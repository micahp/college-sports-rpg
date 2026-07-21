# The U

A top-down 2D mobile college-life RPG. You arrive at North Valley State with
one life, four years, and a walk-on evaluation on Saturday. Every choice
closes a door.

**Play it:** https://micahp.github.io/college-sports-rpg/

**Current build:** Milestone 2 of the Day One vertical slice — a walkable
campus courtyard with three NPCs whose conversations have real choices and
immediate stat consequences. All art is placeholder, generated in code.

## Controls

| | Desktop | Mobile |
|---|---|---|
| Move | WASD / arrow keys | virtual joystick (bottom-left) |
| Talk | E near an NPC | TALK button (appears in range) |
| Advance dialogue | E or click | tap the panel |

## Run it locally

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open this folder in the Godot editor (`project.godot`).
3. Press F5. The main scene is `scenes/world/campus.tscn`.

Mouse clicks emulate touch, so mobile controls are testable on desktop.

## Check it

```
godot --headless -s tests/run_checks.gd          # systems + content validation
godot --headless tests/campus_autoplay.tscn      # input-driven acceptance test
xvfb-run godot tests/screenshot.tscn             # rendered screenshots (build/shots/)
```

## Project map

```
docs/            Constraints (frozen), milestone plan, schemas, definition of done
data/            All narrative + stat effects as JSON — edit story here
  dialogue/      NPC conversations (day1_npcs.json)
  days/          Time-block day beats (Milestone 3 wires these to activities)
scripts/
  core/          Autoloads: InputSetup, GameState, TimeSystem, ContentDB, SaveSystem
  world/         Campus scene, player, NPCs, generated placeholder art
  ui/            HUD, virtual joystick, dialogue panel
scenes/world/    campus.tscn (main), player.tscn, npc.tscn
scenes/app/      Superseded menu prototype (kept for reference; not the game)
tests/           Headless acceptance suites
```

Read `docs/GAME_CONSTRAINTS.md` before changing anything. The game is spatial:
a visible character moving through a visible campus. Menu-driven gameplay was
explicitly rejected — do not reintroduce it.

## Milestones

1. ~~World: map, movement, collision, camera, mobile controls, one NPC~~ ✓ (audit passed)
2. ~~Conversations: three NPCs, dialogue choices, visible stat changes~~ ✓ (awaiting checkpoint)
3. Places and time: building interiors, scene transitions, time periods, activity locking
4. The full day: morning→night sequence, recap, save/continue, regression pass
