# VERDICT — Review Cycle 1

**Commit SHA:** (production build of web-build branch, 2026-07-29)
**Reviewer:** Kallen (Independent QA Director)
**Build command:** `npm run build` (vite build, no typecheck — 1 TS error: `LoopModes` namespace)
**Environment:** Cloudflare tunnel `https://violations-mug-server-initiatives.trycloudflare.com`, Vite preview :4173, 1280x633 viewport, WebGL 2.0 (Chromium), OpenRouter longcat-2.0

---

## VERDICT: REJECTED

The build runs. The game is playable from character creation through campus arrival. But player-facing quality is far below commercial standard. The environment is programmer-art, collision is completely absent, and the JavaScript bundle is large enough to make mobile loading unreliable.

---

## Executive Judgment

This looks like an asset-pack demo: box buildings with flat-shaded surfaces, no architectural detail, no textures, no collision, and a monolithic 3.4 MB JavaScript bundle. A viewer who sees a 15-second clip would think "this looks like a Roblox prototype" — not "I want to play this."

---

## Five Largest Quality Gaps

1. **No collision.** Player walks straight through buildings, props, and likely NPCs. The build ships with Rapier *installed* but no `RigidBody` or `CuboidCollider` on any building, tree, or prop. This is an automatic rejection condition. Physical collision is non-negotiable.

2. **Buildings are textured boxes.** The Recreation Center, dorm, and every other location is a plain rectangular prism with a flat beige color and dark-blue window rectangles. No trim, no architectural depth, no materials, no signage. This is the "decorated box" the rubric calls out as an automatic failure.

3. **3.4 MB JavaScript bundle.** Vite reports `dist/assets/index-BNRCIfvO.js  3,417.22 kB`. On a 3G mobile connection this takes 8–20 seconds to load. No code-splitting, no manualChunks. Three.js, Rapier, and the entire game are one file.

4. **Primitive environment dressing.** Trees appear to be cylinders + spheres. Benches are boxes. The ground is a flat gray plane with a green patch. The campus has no signage, no environmental storytelling, no visual hierarchy. It reads as a generic low-poly park, not a university.

5. **Player character quality unknown.** I have not yet been able to verify if the player character is a properly rigged skinned mesh or primitive geometry. Need a close-up screenshot with the current camera angle.

---

## Automatic Rejection Conditions Triggered

1. **Player passes through buildings, trees, major props, or NPCs.** Confirmed by implementation agent code analysis: zero RigidBody/CuboidCollider components on any building.
2. **The Recreation Center looks like a decorated box.** Confirmed by visual evidence: plain rectangular prism, flat color, no architectural detail.
3. **The campus looks like a park or programmer-art scene.** Confirmed: flat-shaded boxes, no textures, no signage, no environmental storytelling.
4. **Performance too unstable for normal play.** 3.4 MB bundle will cause multi-second freezes on mobile during initial load.

---

## Category Scores

| Category | Score | Evidence |
|---|---|---|
| 1. Player character | TBD | Need close-up; skinned mesh code exists but unverified visually |
| 2. Named characters | TBD | Jordan not yet encountered in this review cycle |
| 3. Campus environment | 2 | Box buildings, flat shading, no textures, no signage |
| 4. Materials and lighting | 3 | Single directional light, hard shadows, no PBR materials |
| 5. Animation | TBD | AnimationController exists; unverified in-game |
| 6. Camera and cinematics | 4 | Functional follow-cam, no cinematic staging observed |
| 7. Interface | 6 | Clean character creation, readable HUD, crisp UI |
| 8. Spatial gameplay | 2 | No collision, no location-based triggers observed |
| 9. Physics and controls | 1 | Rapier installed but not integrated; player passes through everything |
| 10. Basketball | TBD | Not reached in this review |
| 11. Audio | TBD | Not verified |
| 12. Performance | 3 | 3.4 MB bundle, no code-splitting, no LOD |
| 13. Cohesion | 3 | UI is stronger than the 3D world; art direction is inconsistent |
| 14. Desire to play | 2 | Would not share this clip; would not pay for this |

---

## Code Evidence

- `src/components/world/Buildings.tsx` — buildings are `<mesh>` with `<boxGeometry>`, no RigidBody wrapper, no CuboidCollider
- `src/Game.tsx` — imports `Physics, RigidBody, CuboidCollider` from `@react-three/rapier` but only uses them for the ground (unverified)
- `vite.config.ts` — no `manualChunks` configuration, no code-splitting
- `src/components/characters/characterModel.ts` — exports `buildSkeleton, buildSkinnedHumanoid` (code exists, visual result unverified)

---

## Required Corrections (Priority Order)

### P0 — Prevents valid review / breaks the game
- **Collision system.** Wrap every building, major prop, and tree in a fixed `RigidBody` with a matching `CuboidCollider`. Verify the player cannot pass through any geometry by walking into each building from multiple angles.

### P1 — Automatic rejection conditions
- **Building geometry.** Replace box-built buildings with modeled architecture: facades with depth, recessed entrances, roof variation, material sets (brick/concrete/glass), and athletics-specific signage. The Rec Center must read as an athletics building, not a warehouse.
- **Campus dressing.** Add proper trees (not cylinder+sphere), benches with legs, trash cans, light poles, signage, pathways with variation, and environmental storytelling. The campus must feel like a university, not a park.
- **Bundle splitting.** Configure `manualChunks` in vite.config.ts to separate three.js, rapier, react-vendor, and game code. Target <1 MB initial load. Use dynamic imports for basketball, character creator, and other heavy systems.

### P2 — Major commercial-quality gap
- **Player character close-up.** Verify the player character is a properly rigged skinned humanoid with a readable face, natural proportions, clothing, and skeletal animation. If it is primitive geometry, replace it.
- **Jordan encounter.** Verify Jordan appears as a distinct, visually appealing character with personality — not a clone of the player or a primitive mannequin.

### P3 — Noticeable polish defect
- **Lighting.** Add ambient occlusion, softer shadows, and time-of-day variation.
- **Ground textures.** Replace flat gray plane with a textured material (asphalt, concrete, pathways).

---

## Retest Instructions

The next build must provide:
1. Screenshot of player standing in front of a building after walking into it (proving collision)
2. Screenshot of the Rec Center with architectural detail and materials
3. Screenshot of the player character close-up (face visible)
4. Screenshot of Jordan
5. Build log showing bundle <1 MB initial load
6. Video of player walking into 3 different buildings and stopping
