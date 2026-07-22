# The U

A stylized 3D mobile college-life RPG. You arrive at North Valley State with
one life, four years, and a walk-on evaluation on Saturday. Every choice
closes a door.

**Play it:** https://micahp.github.io/college-sports-rpg/

**Current build:** Milestone 1.6 — the postable campus slice. An
editor-authored 3D courtyard at North Valley State: the Rec Center as the hero
building, navy-and-gold Ridgehawks branding (banners, monument sign, bulletin
board, club table, plaza emblem), six background students living the space,
soft art-directed lighting, ambient audio, and one cinematic conversation with
Jordan that eases into a profile two-shot. The goal is a screenshot and a
15-second clip that read as a real university-life sports RPG without a
prototype disclaimer.

The full simulation from the earlier 2D milestones (three NPCs, dialogue
choices, stat effects) is archived systems validation — its tests still pass;
it gets rewired into this presentation in Milestone 3.

## Controls

| | Desktop | Mobile |
|---|---|---|
| Move | WASD / arrow keys | virtual joystick (bottom-left) |
| Talk | E near Jordan | TALK button (appears in range) |
| Close dialogue | E / click Continue | tap Continue |

## Run it locally

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open this folder in the Godot editor (`project.godot`).
3. Press F5. The main scene is `scenes/world3d/campus3d.tscn`.

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
assets/          CC0 Quaternius models/textures + generated branding/audio/ground
data/            All narrative + stat effects as JSON — edit story here
tools/           Repeatable generators: asset fetch, branding, audio, scene scaffold
scripts/
  core/          Autoloads: InputSetup, GameState, TimeSystem, ContentDB, SaveSystem
  world3d/       Campus behavior, player, NPCs, background students, appearance
  world/         Archived 2D top-down milestone (systems proof, not shipped)
  ui/            HUD, virtual joystick, dialogue panels
scenes/world3d/  campus3d.tscn (main scene) + env/ subscenes + actors
tests/           Headless acceptance suites + screenshot/clip rigs
```

The courtyard is an editor-authored scene. Regenerate its scaffold — and the
branding, audio, and ground textures it uses — with:

```
python3 tools/make_branding.py                   # North Valley State textures
python3 tools/make_audio.py                      # ambient bed, footsteps, UI
godot --headless -s tools/build_campus_scene.gd  # (re)write campus3d.tscn + env/
```

Read `docs/GAME_CONSTRAINTS.md` and `docs/ART_PIPELINE.md` before changing
anything. The game is spatial and must look like a product: no primitive-shape
characters, no menu-driven gameplay, fixed camera, mobile controls always.

## Milestones

1. ~~World: map, movement, collision, camera, mobile controls, one NPC~~ ✓ (audit passed)
2. ~~Conversations: three NPCs, dialogue choices, visible stat changes~~ ✓ (2D, systems archived)
1.5. ~~Visual target: stylized 3D courtyard, real humans~~ ✓ (superseded by 1.6)
1.6. ~~Postable campus slice: branded courtyard, background life, cinematic dialogue, audio~~ ✓ (awaiting checkpoint)
3. Rewire M2 conversations + stats into the 3D campus; building interiors, time periods
4. The full day: morning→night sequence, recap, save/continue, regression pass
