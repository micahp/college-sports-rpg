# Definition of Done — Day One Prototype

A build passes when every box checks:

## Playable loop
- [ ] Player enters a name and picks an identity; both affect the run.
- [ ] Player completes all four periods of Day 1 with a real choice in each.
- [ ] At least one option is visibly locked when energy is too low, with the reason shown.
- [ ] Every choice updates the stats bar immediately and shows a reaction line
      with the stat deltas spelled out.
- [ ] The recap screen names the player, their identity, a primary trait derived
      from their choice tags, and at least one specific choice they made.
- [ ] "Play Again" starts a clean run.

## Systems
- [ ] Time only advances when a choice resolves; the header always shows Day + Period.
- [ ] Stats clamp to 0–100 — no negative energy, no 110 relationships.
- [ ] The game autosaves after every choice; force-quitting mid-day and
      relaunching resumes at the same beat with the same stats.
- [ ] All Day 1 content comes from `data/` — changing JSON text changes the game
      with no script edits.
- [ ] `godot --headless -s tests/run_checks.gd` exits 0.

## Feel (playtest with 5 people)
- [ ] They understood what to do without instructions.
- [ ] They can name the choice that felt hardest.
- [ ] They wanted to replay with different choices — this is the ship/no-ship signal.
