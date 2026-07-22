# The U

A stylized 3D mobile college-life RPG. You arrive at North Valley State with
one life, four years, and a walk-on evaluation on Saturday. Every choice
closes a door.

**Play it:** https://micahp.github.io/college-sports-rpg/

**Current build:** Milestone 1.5 — the visual target prototype. A composed 3D
campus courtyard (fixed three-quarter camera, warm afternoon light, real
low-poly humans from CC0 Quaternius packs) with movement, collision, and one
conversation with Jordan. The full simulation from the earlier 2D milestones
(three NPCs, dialogue choices, stat effects) is intact and gets rewired into
this presentation next.

## Controls

| | Desktop | Mobile |
|---|---|---|
| Move | WASD / arrow keys | virtual joystick (bottom-left) |
| Talk | E near Jordan | TALK button (appears in range) |
| Close dialogue | E / click Continue | tap Continue |

## Run it locally

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open this folder in the Godot editor (`project.godot`).
3. Press F5. The main scene is `scenes/world/campus.tscn`.

Mouse clicks emulate touch, so mobile controls are testable on desktop.

## Check it

```
godot --headless -s tests/run_checks.gd          # systems + content validation
godot --headless tests/campus3d_autoplay.tscn    # 3D slice acceptance test
godot --headless tests/campus_autoplay.tscn      # 2D milestone regression
xvfb-run godot tests/screenshot3d.tscn           # rendered stills (build/shots3d/)
xvfb-run godot --write-movie build/clip/clip.avi --fixed-fps 30 tests/clip3d.tscn
```

## Project map

```
docs/            Constraints, milestone plan, ART_PIPELINE.md, schemas, DoD
assets/          CC0 Quaternius models/textures (see docs/ART_PIPELINE.md)
data/            All narrative + stat effects as JSON — edit story here
scripts/
  core/          Autoloads: InputSetup, GameState, TimeSystem, ContentDB, SaveSystem
  world3d/       3D campus, player, NPCs (current presentation)
  world/         2D top-down milestone (systems proof, superseded presentation)
  ui/            HUD, virtual joystick, dialogue panels
scenes/world3d/  campus3d.tscn (main scene)
tests/           Headless acceptance suites + screenshot/clip rigs
```

Read `docs/GAME_CONSTRAINTS.md` and `docs/ART_PIPELINE.md` before changing
anything. The game is spatial and must look like a product: no primitive-shape
characters, no menu-driven gameplay, fixed camera, mobile controls always.

## Milestones

1. ~~World: map, movement, collision, camera, mobile controls, one NPC~~ ✓ (audit passed)
2. ~~Conversations: three NPCs, dialogue choices, visible stat changes~~ ✓ (2D, systems kept)
1.5. ~~Visual target: stylized 3D courtyard, real humans, postable screenshot/clip~~ ✓ (awaiting checkpoint)
3. Rewire M2 conversations + stats into the 3D campus; building interiors, time periods
4. The full day: morning→night sequence, recap, save/continue, regression pass
