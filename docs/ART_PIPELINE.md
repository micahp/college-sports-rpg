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
| Player (casual tee) | Animated Men — `Male_Casual.fbx` | quaternius.com (Drive) |
| Jordan (shirt) | Animated Men — `Male_Shirt.fbx` | quaternius.com (Drive) |
| 11 shared animations | embedded in the FBX (Idle/Walk/Run/Sit…) | — |
| Buildings, door | Downtown City MegaKit | quaternius.itch.io |
| Trees, bushes, flowers | Stylized Nature MegaKit | quaternius.itch.io |
| Bench, trashcan, streetlight, flag | Quaternius singles | poly.pizza |
| (spare) superhero bodies + hair | Universal Base Characters + UAL | quaternius.itch.io |

All by **Quaternius** (quaternius.com), released CC0 1.0. Thank you, Quaternius.

## Ingest recipe (repeatable)
1. itch.io packs: `scratchpad/fetch_packs.py` automates the widget flow.
2. Older packs: Google Drive folders via `gdown --folder` (quota-limited; retry later).
3. Single props: poly.pizza model pages → `static.poly.pizza/*.glb.br`
   (needs `Accept-Encoding: br`, then brotli-decompress).
4. Copy only needed models + their referenced textures into `assets/<category>/`.
5. Downscale textures >1024px (PIL), then `godot --headless --import`.
6. Verify with `tests/inspect_assets.gd` (node tree + animation list + AABBs).

## Composition notes (campus3d.gd)
- Fixed camera: pitch −46°, yaw 22°, distance 21.5, FOV 31 — do not let it rotate.
- Sun: warm (1.0, 0.9, 0.76) at (−38°, −58°), energy 1.25, shadows on;
  sky ambient 0.85, filmic tonemap.
- Every frame should have foreground (bush/tree), midground (actors), and
  background (building/facade) elements.
