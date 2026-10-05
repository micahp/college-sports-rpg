# The U

A stylized 3D mobile college-life RPG. You arrive at North Valley State with
one week, one roommate, and a walk-on basketball evaluation on Saturday.
Every choice closes a door.

**Play it:** https://micahp.github.io/college-sports-rpg/

## The game

- **Title → character creation.** Name, how you got here (Workhorse /
  Natural Talent / Scholar — each shifts your starting stats), and one of four
  looks. Continue picks up an autosave exactly where you left it.
- **Seven days, four periods each** (Sunday move-in → Saturday tryout). Time
  only moves when you finish an activity — walking around is free.
- **A walkable campus.** The quad hub plus three interiors behind real doors:
  Hargrove Hall Room 214 (your dorm), Moreno Hall 104 (Intro to Kinesiology),
  and the Rec Center court and weight room.
- **Activities** at spots in the world: study, nap, attend lecture, office
  hours, shootaround, pickup runs, conditioning, the club fair. Each costs the
  period and moves your six stats (energy, academics, athleticism,
  basketball, your relationship with Jordan, coach interest). Skills have
  diminishing returns — you can't max everything in a week.
- **Story, face to face.** Jordan (roommate), Dee (orientation leader),
  Coach Delgado and Prof. Okafor show up at specific places and times with
  choices that matter: sign the walk-on sheet (or don't), Jordan's volleyball
  match vs. Delgado's conditioning session on the same night, Dee's study
  group, the Thursday floor party, the Friday quiz that decides eligibility.
  A gold **!** marks someone with something new to say; a gold arrow points to
  your current objective.
- **Shooting minigame** (timing meter — release in the gold zone). Zone width
  comes from basketball skill, sweep speed from athleticism and energy. Used
  for shootarounds, the Thursday showcase in front of Delgado, and the
  three-station Saturday evaluation.
- **Nightly recap** of what changed, and an **ending** with five possible
  verdicts (made the roster, made it on academic review, practice squad, cut,
  watched from the bleachers) plus epilogues for Jordan, your grades, and the
  kind of week you had.

## Controls

| | Desktop | Mobile |
|---|---|---|
| Move | WASD / arrow keys | virtual joystick (bottom-left) |
| Talk / enter / use | E, Space or Enter near someone or something | action button (bottom-right) |
| Pick a choice | click, or number keys 1–4 | tap |
| Shoot | Space / E, or click SHOOT | tap SHOOT |
| Stats / pause | STATS and MENU buttons (top-right) | same |

## Run it locally

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open this folder in the Godot editor (`project.godot`).
3. Press F5. The main scene is `scenes/app/title.tscn`.

Mouse clicks emulate touch, so mobile controls are testable on desktop.

## Check it

```
godot --headless -s tests/run_checks.gd           # systems + content validation
godot --headless tests/week_autoplay.tscn         # plays the whole week 4 ways + save/continue
xvfb-run godot --rendering-driver opengl3 tests/tour_shots.tscn     # every location (build/tour/)
xvfb-run godot --rendering-driver opengl3 tests/moment_shots.tscn   # UI moments (build/moments/)
```

`week_autoplay` drives the real scenes with a scripted player: walking,
collision, the joystick, every story card, the minigame, recaps, all four
strategies reaching an ending (roster, roster-or-better for a scholar, cut for
a player who misses every shot, bleachers for one who never signs up), then
quit-to-title → Continue restoring day, period, place, stats and history.

## Project map

```
data/            All story, activities, NPCs, looks, endings (JSON) — edit the game here
  story/         events.json (week's conversations + ambient chatter), endings.json
  world/         activities.json (spots + choices), npcs.json (who + how they look)
  characters/    identities.json, looks.json
scripts/
  core/          Autoloads: InputSetup, GameState, TimeSystem, ContentDB, SaveSystem, Game
  world3d/       location.gd (runs every place), player, NPCs, students, appearance
  minigame/      shot_minigame.gd
  ui/            ui_kit, game_ui (HUD/stats/menu/recap), story_card, joystick
  app/           title + character creation, ending
scenes/          app/ (title, ending), world3d/ (quad + actors), interiors/
tools/           Generators: campus + interiors scenes, textures, branding, audio, portraits
tests/           Headless acceptance suites + screenshot rigs
docs/            Constraints, schemas, art pipeline, definition of done
```

Scenes are generated scaffolds — regenerate after editing the generators:

```
godot --headless -s tools/build_campus_scene.gd   # scenes/world3d/campus3d.tscn + env/
godot --headless -s tools/build_interiors.gd      # scenes/interiors/*.tscn
python3 tools/make_interiors.py                   # floor textures
xvfb-run godot --rendering-driver opengl3 tools/render_portraits.tscn   # portraits + title art
```

Story is data: to add a conversation, add an entry to `data/story/events.json`
(day, periods, location, spot, lines, choices). See `docs/DATA_SCHEMAS.md`.
