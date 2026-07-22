# Art Direction & Asset Pipeline

Locked 2026-07-21 (Micah's pick): **stylized low-poly humans, warm and
grounded** — proportioned characters, modern campus architecture, dense
greenery, late-afternoon sun. Not chunky/voxel, not realistic.

## Rules
- No stick figures, capsules, or primitive-shape characters anywhere visible.
- All humans share the Quaternius rig style; player and NPCs must differ in
  model, hair, and clothing colors (distinct silhouettes).
- Environment art comes from the packs below; code-generated geometry is only
  allowed for ground planes, paths, and invisible colliders.
- Godot 4.3 imports FBX natively (ufbx) and glTF natively; GLB from poly.pizza
  works as-is. Textures ≤1024px (downscaled on ingest to keep web builds sane).
- Fictional branding only: North Valley State, Ridgehawks, navy #1F335C + gold #EBB84D.

## Sources (all CC0, no attribution required — credited anyway)

| What | Pack | Where |
|---|---|---|
| Player + male background students | Animated Men — `Male_Casual/Shirt/LongSleeve/Suit.fbx` | quaternius.com (Drive) |
| Female background students | Animated Women — `Female_Casual/TankTop/Dress/Alternative.fbx` | quaternius.com (Drive) |
| 11 shared animations (per sex) | embedded in the FBX (Idle/Walk/Run/Sit…) | — |
| Buildings, door, stairs, bollard, planters | Downtown City MegaKit | quaternius.itch.io |
| Trees, bushes, flowers, grass, clover | Stylized Nature MegaKit | quaternius.itch.io |
| Bench, trashcan, streetlight, flag, backpack, table | Quaternius singles | poly.pizza |
| (spare) superhero bodies + hair | Universal Base Characters + UAL | quaternius.itch.io |

Characters are one shared rig recolored per instance by surface name
(`character_appearance.gd`): Skin/Hair/Shirt/Pants → distinct silhouettes
from one FBX. The player carries a recolored backpack; the Ridgehawk flags
reuse the CC0 flag mesh recolored to navy + gold (`recolor.gd`).

All by **Quaternius** (quaternius.com), released CC0 1.0. Thank you, Quaternius.

## Ingest recipe (repeatable)
1. itch.io packs: `tools/fetch_packs.py` automates the widget flow
   (edit the PACKS list and the OUT path, then `python3 tools/fetch_packs.py`).
2. Older packs: Google Drive folders via `gdown --folder` (quota-limited; retry later).
3. Single props: poly.pizza model pages → `static.poly.pizza/*.glb.br`
   (needs `Accept-Encoding: br`, then brotli-decompress).
4. Copy only needed models + their referenced textures into `assets/<category>/`.
5. Downscale textures >1024px (PIL), then `godot --headless --import`.
6. Verify with `tests/inspect_assets.gd` (node tree + animation list + AABBs).

## Tooling on a fresh machine
- Godot 4.3 Linux binary (headless-capable):
  `curl -sLO https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip`
- Web export templates (extract `templates/web_*` + `templates/version.txt` to
  `~/.local/share/godot/export_templates/4.3.stable/`):
  `Godot_v4.3-stable_export_templates.tpz` from the same release page.
- Visual review without a display: `xvfb-run` + `LIBGL_ALWAYS_SOFTWARE=1`
  + `--rendering-driver opengl3` (see tests/screenshot3d.gd and tests/clip3d.gd).
- Deploy = export Web preset, copy `build/shots3d` + clip into `build/web`,
  force-push `build/web` contents as the `gh-pages` branch.

## Scene authoring (Milestone 1.6)
The courtyard is an **editor-authored scene**, `scenes/world3d/campus3d.tscn`,
built from reusable subscenes in `scenes/world3d/env/` (rec_center,
campus_sign, info_board, club_table, pole_banner) plus `player3d.tscn`,
`npc3d.tscn`, and `student.tscn`. `scripts/world3d/campus3d.gd` holds runtime
behavior only (camera follow, conversation move, interaction, audio) — it does
**not** place environment nodes.

Regenerate the scaffold with `godot --headless -s tools/build_campus_scene.gd`;
after that the `.tscn` files are the source of truth and can be opened and
tweaked by eye in the Godot editor. Marker positions and prop placements live
in that generator, one deliberate composition choice per line — never a random
scatter of important visual elements.

Branding and ground textures are generated procedurally and CC0-safe:
`tools/make_branding.py` (emblem, banners, posters, plaza decal) and the
`assets/ground/` grass. Presentation audio: `tools/make_audio.py` (ambient
bed, footsteps, UI sounds).

## Composition notes
- Fixed gameplay camera: pitch −38°, yaw 20°, distance 20.5, FOV 33, with a
  north look-ahead so the frame favors the destination, not empty ground.
  Do not let it rotate.
- Conversation camera: eases perpendicular to the speakers' line for a
  profile two-shot (pitch −33°, distance 10.5), then restores.
- Sun: warm (1.0, 0.93, 0.82) at (−52°, −38°), energy 1.1, soft shadows
  (opacity 0.6, blur 2.0); a cool low fill light lifts shadowed sides; sky
  ambient 1.05, filmic tonemap. Grass and pavement are desaturated so the
  scene reads as art-directed, not toy-like.
- Every frame should have foreground (bush/tree), midground (actors), and
  background (building/facade) elements.
