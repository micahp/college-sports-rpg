# ADVERSARIAL QUALITY RUBRIC — The U

Date: 2026-07-29
Reviewer: Kallen (QA Director — independent)
Branch: web-build
Commit: TBD (current HEAD)

## Core Standard

The U is a browser-first 3D college-life sports RPG. It must be visually exceptional, emotionally engaging, mechanically polished, technically sound, and cohesive. A viewer seeing a short clip should immediately think "I want to play this."

The game FAILS if a viewer thinks:
- this looks like programmer art
- this looks like an asset-pack demo
- this looks like an AI-generated prototype
- this looks like a collection of menus
- the interface looks better than the actual game

## Reference Games

TBD per review cycle — modern sports career modes, life simulators, campus environments, premium UI.

## Evidence Requirements

Per review cycle (timestamped folder): environment.json, console.log, typecheck.log,
build.log, performance.json, CODE_AUDIT.md, VISUAL_AUDIT.md, GAMEPLAY_AUDIT.md,
REGRESSION_AUDIT.md, VERDICT.md, VERDICT.md, VERDICT.json, plus screenshots/video
in designated subfolders.

## Scoring (0–10)

0=Missing | 1=Embarrassing placeholder | 2=Severe prototype | 3=Poor | 4=Below commercial
5=Ordinary | 6=Competent indie | 7=Strong indie | 8=Professional commercial
9=Excellent polished | 10=Category-leading

## Auto-Rejection Conditions

- Foreground human from primitive geometry
- Named characters lack skeletal animation
- Walking = whole-body bobbing only
- Player passes through buildings/trees/NPCs
- Recreation Center = decorated box
- Campus looks like a park/programmer-art
- Interface far stronger than 3D game
- Story beats from arbitrary timers (only)
- Campus is just a backdrop
- Basketball = only a timing bar (only)
- Mobile controls broken
- Build has severe console/render errors
- Unclear asset licensing
- Evidence omits known weak states
- Performance unstable
- Game not completable end-to-end

## Approval Requirements

- No auto-rejection conditions
- Player character: character ≥9, named characters ≥8, environment ≥9, animation ≥8,
  camera ≥8, interface ≥8, spatial ≥8, physics ≥8, cohesion ≥9, desire-to-play ≥9
- Stable end-to-end completion and acceptable desktop/mobile performance
- Blind visual judge finds it professional

## Verdict Categories

- BLOCKED: Cannot be reviewed (missing/critical break)
- REJECTED: Below bar
- CONDITIONALLY APPROVED: Narrow milestone, no auto-rejections
- APPROVED: Meets full commercial standard

RUBRIC.md
echo "RUBRIC created"
