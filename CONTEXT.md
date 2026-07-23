# The U — Three.js Rebuild: Session Context (2026-07-22)

## Where we are

Repo: /root/college-sports-rpg, branch `threejs`. Clean-slate browser-first
rebuild of The U (college-life sports RPG) approved by Micah. Godot history
stays on `main`; all Godot files deleted in working tree (uncommitted deletions
— do NOT commit the deletions until the new build stands on its own).

## What's built and WORKING (verified)

- Vite + React 18 + TS + three@0.169 + R3F + Drei + Zustand. `npm run build`
  passes, `tsc -p tsconfig.json --noEmit` clean. (The write_file linter is
  broken — references ../node_modules and stale lib config. IGNORE it; real
  tsc is source of truth.)
- Playable loop: title → character creation (name + identity card w/ stat
  effects) → auto-presented Day 1 narrative beats (4 periods, data-driven from
  data/days/day_1.json) → choices with energy requirements → reaction cards
  with stat pills → recap screen with primary-trait summary + replay.
- 3D quad: ground/plaza/walkways, Rec Center + Hargrove Hall + Moreno Hall
  (canvas-texture name banners), trees, benches, club table, banner poles,
  emblem decal. 6 background students with routines (walk ping-pong / sit /
  chatting pairs).
- Player: WASD/arrows + touch joystick, walk bob, campus bounds clamp,
  character-focused camera (just tuned: dist 3.1, height 1.9, look-ahead).
- NPCs Jordan/Dee/Coach: proximity rings, dialogue panels with the real
  day1_npcs.json content, one-shot choices → stat effects, repeat lines after.
- Custom character builder (src/game/characters.ts): ~1.75u stylized figures,
  per-cast specs (skin/hair styles incl. curls/locs/ponytail/fade/bun, jersey/
  hoodie/jacket, accessories, build). Jordan wears gold Ridgehawks jersey —
  readable at a glance. NO Quaternius character FBX (rejected in handoff).
- Assets restored from main → public/assets/ (Vite serves from public/ —
  that's why they 404'd at first): audio, branding PNGs, city/nature glTF,
  props glb. Quaternius = CC0.
- Screenshot pipeline: tools/screenshot.mjs (playwright, chromium at
  /root/.cache/ms-playwright). Preview server: `npm run preview -- --port 4173`
  (currently running as background proc proc_8aece00af226). shots/ has
  01_title → 06_free_roam.

## The problem to solve NEXT (top priority)

The 3D scene is the weak link — same failure mode as the Godot version:
empty-looking world, flat lighting, distant feel. UI layer is already
shippable; 3D is not. Handoff lesson #2: prove the visual target BEFORE
building more systems.

Just applied (in dist when interrupted): golden-hour lighting pass
(warm sun #ffc078 @ [24,14,12], sky #e8a85c, fog #e8b070, warm hemisphere)
+ closer camera. NOT yet re-screenshotted — the build+screenshot command got
interrupted at the screenshot step.

Next iteration targets, in order:
1. Verify golden-hour + close camera with fresh screenshots
   (`node tools/screenshot.mjs game` after `npm run build`).
2. Ground treatment: path network variation, brick/concrete texture mix,
   break up the flat grass + circle plaza.
3. Density with intent: more social clusters of students near club table /
   benches, bikes, flyers/posters on boards, crosswalk striping.
4. Rec Center hero pass: entrance stairs, awning, window band variation,
   stronger silhouette.
5. Character close-up check: are silhouettes/faces readable at new camera
   distance? If not, iterate on the builder before adding content.

## Key files

- src/game/store.ts — zustand game state: stats (6 canonical keys), phases
  (title/create/play/beat/reaction/recap), beats drive the 4-period clock.
- src/game/content.ts — loads data/ JSON (day1 beats, npcs, identities).
- src/game/characters.ts — CAST specs + buildCharacter(). mulberry-seeded.
- src/game/Campus.tsx — all environment. Sky() has the lighting rig.
- src/game/Player.tsx — controller + camera + inputVector shared w/ joystick.
- src/game/Npcs.tsx — placements + proximity (writes useProx store).
- src/game/prox.ts — nearNpc/talkingTo shared between canvas and HTML UI.
- src/game/Students.tsx — background NPC routines.
- src/ui/Ui.tsx + styles.ts — all HTML overlay UI (premium navy/gold, Archivo
  + Inter fonts). Touch joystick lives here too.
- src/App.tsx — phase router + ObjectiveToast (auto-presents current beat).
- docs/ (from main): GAME_CONSTRAINTS (engine-locked parts now stale; sim
  rules still apply), VERTICAL_SLICE, ART_PIPELINE, DATA_SCHEMAS.
- THE_U_HANDOFF.md — Micah's handoff. READ FIRST. Lessons: characters are the
  product; camera close; no Quaternius humans; no sunk-cost defense.

## Data/contracts to preserve

- Six stats: energy academics athleticism basketball_skill
  roommate_relationship coach_interest (0–100, clamped ints).
- Beats: period morning|afternoon|evening|night, choices have effects/tags/
  requirements.energy_min; tags feed recap primary trait.
- Branding: navy #1F335C + gold #EBB84D. North Valley State / Ridgehawks.
- Micah owns git: NEVER commit without permission.

## Running

- Preview: `npm run preview -- --port 4173 --host 127.0.0.1` (background).
- Screenshots: `node tools/screenshot.mjs all|title|create|game`.
- Tests not yet written (vitest installed). Audio not yet wired (files exist
  in public/assets/audio).
