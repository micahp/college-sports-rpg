# Asset License Record — The U

Last updated: 2026-07-22

All assets are CC0 or original unless noted. Acknowledgment is listed per the
art pipeline doc; CC0 does not legally require attribution, but the creators
deserve credit.

## 3D Models

| Asset | Creator | Source | License | Modifications | Used In |
|---|---|---|---|---|---|
| Downtown City MegaKit (buildings, doors, stairs, planters, bollards, sidewalks) | Quaternius | quaternius.itch.io | CC0 1.0 | Unmodified glTF; textures downscaled to ≤1024px | Campus buildings, Rec Center entrance |
| Stylized Nature MegaKit (trees, bushes, grass, clover, flowers) | Quaternius | quaternius.itch.io | CC0 1.0 | Unmodified glTF; textures downscaled | Campus greenery |
| Props (bench, trashcan, streetlight, flag, backpack, table) | Quaternius | poly.pizza (singles) | CC0 1.0 | GLB used as-is | Plaza props, player backpack |
| Character figures | Original (Kallen) | Procedurally generated in src/game/characters.ts | Original | Built from Three.js primitives (CapsuleGeometry, SphereGeometry, etc.) — no third-party character models | All human characters (player, NPCs, background students) |

## Textures

| Asset | Creator | Source | License | Modifications | Used In |
|---|---|---|---|---|---|
| T_Grass_Soft.png | Quaternius | Nature MegaKit | CC0 1.0 | Referenced but not currently applied (flat-colored alternative used) | Reserved for ground detail pass |
| City building textures (Concrete, Brick, Trim, Marble, Metal, Roof, interior atlas) | Quaternius | Downtown City MegaKit | CC0 1.0 | Available; not yet wired (buildings use flat materials for the stylized look) | Reserved for building detail |

## Branding

| Asset | Creator | Source | License | Modifications | Used In |
|---|---|---|---|---|---|
| North Valley State emblem, banners, posters, plaza decal | Original (procedurally generated) | tools/make_branding.py | Original | Python PIL-generated from fictional design spec (navy #1F335C, gold #EBB84D, Ridgehawk bird) | All campus signage, title screen, HUD |

## Audio

| Asset | Creator | Source | License | Modifications | Used In |
|---|---|---|---|---|---|
| ambient_campus.ogg | Original (procedurally generated) | tools/make_audio.py | Original | Generated via pydub tone/sweep layers | Background ambient loop |
| footstep_1–4.ogg | Original (procedurally generated) | tools/make_audio.py | Original | Click/pulse layers | Player movement SFX |
| ui_open/confirm/close.ogg | Original (procedurally generated) | tools/make_audio.py | Original | Short tone sweeps | UI interaction feedback |

## Fonts

| Asset | Creator | Source | License | Used In |
|---|---|---|---|---|
| Inter | Rasmus Andersson | Google Fonts | SIL OFL 1.1 | Body text, UI |
| Archivo | Omnibus-Type | Google Fonts | SIL OFL 1.1 | Headers, buttons, branding |

## Code Libraries

All npm dependencies are MIT or Apache 2.0 licensed — verified at install time
via package.json. Key dependencies: three.js (MIT), React Three Fiber (MIT),
Zustand (MIT), Rapier (Apache 2.0/MIT).

## Compliance

- No real university names, trademarks, mascots, logos, uniforms, or building designs are used.
- North Valley State and Ridgehawks are original fictional identities.
- No AI-generated imagery is used in final assets — all visuals are
  procedurally constructed from geometry or generated via deterministic PIL scripts.
- Character models are NOT the Quaternius FBX characters (those were rejected;
  the character builder creates original stylized figures from Three.js primitives).
