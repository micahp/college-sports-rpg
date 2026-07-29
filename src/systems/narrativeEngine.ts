/**
 * systems/narrativeEngine.ts — drives Week 1 story progression.
 * Each frame, checks if any unmet StoryBeat's conditions are satisfied by the
 * current game state + player location. If so, fires the beat: starts dialogue,
 * applies consequences. Respects 'once' so beats don't refire.
 */
import { WEEK1_BEATS, evaluateOutcome, type StoryBeat, type Consequence } from '../data/narrative';
import { useGameStore } from '../store/gameStore';

let firedBeats = new Set<string>();

export function resetNarrative() {
  firedBeats = new Set();
}

/** Call every frame from inside the Canvas. */
export function tickNarrative() {
  const gs = useGameStore.getState();
  if (gs.phase !== 'playing') return;
  if (gs.ui.dialogueActive) return;

  for (const beat of WEEK1_BEATS) {
    if (beat.once && firedBeats.has(beat.id)) continue;

    // Time window check
    if (gs.day !== beat.day) continue;
    const hourEnd = beat.hourEnd ?? beat.hour;
    if (gs.hour < beat.hour || gs.hour > hourEnd) continue;

    // Location check
    if (beat.location !== 'any' && gs.location !== beat.location) continue;

    // Condition check
    if (beat.trigger) {
      if (beat.trigger.flag && !gs.flags[beat.trigger.flag]) continue;
      if (beat.trigger.statGte) {
        for (const [stat, val] of Object.entries(beat.trigger.statGte)) {
          if ((gs.stats as any)[stat] < val) continue;
        }
      }
    }

    // Fire the beat
    firedBeats.add(beat.id);
    fireBeat(beat);
    break; // one beat per frame
  }
}

function fireBeat(beat: StoryBeat) {
  const store = useGameStore.getState();
  // Apply immediate consequences (decisions are surfaced via dialogue)
  applyConsequence(beat.consequence, store);
  // Notify player
  if (beat.consequence.notify) {
    store.notify(beat.consequence.notify);
  }
  // Set quest/active objective
  store.activeQuest = beat.id;
  // Start the beat's dialogue
  store.startDialogue(beat.dialogueId);
}

function applyConsequence(c: Consequence, store: ReturnType<typeof useGameStore.getState>) {
  if (c.statChanges) {
    for (const [stat, delta] of Object.entries(c.statChanges)) {
      store.modifyStat(stat as any, delta);
    }
  }
  if (c.flags) {
    for (const [k, v] of Object.entries(c.flags)) {
      store.setFlag(k, v);
    }
  }
  if (c.relationshipChanges) {
    for (const [id, changes] of Object.entries(c.relationshipChanges)) {
      store.updateRelationship(id, changes);
    }
  }
  if (c.travelTo) {
    store.travelTo(c.travelTo);
  }
}

/** Evaluate the tryout outcome — called when the final beat fires. */
export function evaluateTryoutOutcome() {
  const s = useGameStore.getState();
  return evaluateOutcome(
    { ...s.stats, money: s.stats.money, reputation: s.stats.reputation } as any,
    { ...s.flags },
    { ...s.relationships } as any
  );
}

export { WEEK1_BEATS };
