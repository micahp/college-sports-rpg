# The U — Milestone Summary

**Date:** 2026-07-29
**Branch:** web-build
**Final commit:** 450c43e
**Status:** Milestone Complete — Playable First Week

---

## What Was Built

A browser-first 3D college-life sports RPG. The player arrives at North Valley State University, creates a character, and begins their first week as a student-athlete trying to make the basketball team.

## Playable Loop

1. Create a character (name, pronouns, appearance, identity, personality, motivation)
2. Arrive on campus — spawn at the outdoor basketball court
3. Explore the campus on foot (WASD + collision)
4. Press E near the court to play basketball
5. Encounter Jordan Hayes — first relationship, dialogue triggers
6. Manage time, energy, and money via the in-game phone
7. Use the phone map to teleport to 7 locations (Dorm, Rec, Gym, STEM, Dining, Union, Library)
8. Check schedule, messages, team info, and profile

## Technical Stack

- Three.js + React Three Fiber + Drei
- React + TypeScript
- React Three Rapier (physics)
- Zustand (state management)
- Vite (build)
- Cloudflare Tunnel (deployment)

## Architecture

- 36 TS/TSX source files
- Modular component structure (World, Player, UI, Systems)
- State management via Zustand stores (gameStore, inputStore)
- Rapier physics with fixed colliders for buildings, capsule collider for player
- Instanced rendering for trees and benches (150 trees, 12 draws)
- Code-split bundle: 18.9 KB gzip initial load
- 5 building variants with distinct materials and roof geometry
- 21 NPCs with daily schedules and appearance parameters
- Audio system with location-based ambient and SFX

## What Works

- Character creation (6-step flow)
- Third-person movement with collision
- Basketball interaction prompt
- Jordan NPC with dialogue
- Phone with map/teleport/schedule/messages/team/profile
- Time/day/energy/money systems
- Building variants (trim, foundation, roof geometry)
- Trees, benches, flag poles, food truck, court
- Audio system (footsteps, basketball, ambient)
- Bundle optimization (split chunks)

## Known Gaps (non-blocking)

- FPS counter display bug (reads 1 FPS, actual performance unmeasured)
- NPCs exist in code but visual spawn not confirmed in browser
- Basketball gameplay loop not visually verified
- Mobile controls not verified
- Visual polish (AO, materials, facial detail) at prototype quality

## Next Steps for Premium Quality

1. Lighting pass (ambient occlusion, softer shadows, exposure tuning)
2. Player character upgrade (face detail, clothing materials, better mesh)
3. Basketball gameplay (shooting, scoring, feedback, teammate AI)
4. NPC visual verification and density
5. Mobile controls and responsive layout
6. Performance measurement and optimization
7. Environmental storytelling and campus density

## Review History

- Review 1: REJECTED (no collision, 3.4MB bundle, programmer art)
- Review 2: CONDITIONALLY APPROVED (collision, bundle split, building variants)
- Review 3: CONDITIONALLY APPROVED (movement, trees, ground textures, clothing)
- Review 4: CONDITIONALLY APPROVED (basketball prompt, phone/map, Jordan dialogue)

All auto-rejection conditions cleared. Average category score: 5.6/10.
Target for premium release: 8/10 across all categories.
