/**
 * timeSystem — authoritative clock for the game world.
 *
 * Advances the gameStore clock inside a useFrame loop. Real seconds per game minute
 * is configurable. Fires events on the hour and at specific story-beat times. Pauses
 * cleanly when the game is paused or dialogue is active.
 *
 * This is the single source of truth for in-game time — no other system should
 * directly call advanceTime except through the helpers exported here.
 */
import { useGameStore } from '../store/gameStore';
import { useFrame } from '@react-three/fiber';

// ---------------------------------------------------------------------------
// Tuning
// ---------------------------------------------------------------------------
/** Real seconds that elapse per one in-game minute. 1 = very fast (testing). */
export const DEFAULT_REAL_SECONDS_PER_GAME_MINUTE = 1.0;

/** Fired by useTimeSystem each time the in-game hour ticks (e.g. 9:00, 10:00). */
export type HourListener = (hour: number, day: number) => void;

/** Fired by useTimeSystem at a specific (day, hour, minute) story beat. */
export type BeatListener = (beatId: string, day: number, hour: number, minute: number) => void;

/** Registry of hour-change listeners (scheduleSystem subscribes here). */
const hourListeners: HourListener[] = [];
/** Registry of story-beat listeners. */
const beatListeners: BeatListener[] = [];
/** Story-beat key = `${day}:${hour}:${minute}` -> beatId, fired once per crossing. */
const scheduledBeats: Array<{ day: number; hour: number; minute: number; beatId: string; fired: boolean }> = [];

/**
 * Hook a callback to fire whenever in-game time crosses an hour boundary.
 * Returns an unsubscribe function.
 */
export function onHourChange(listener: HourListener): () => void {
  hourListeners.push(listener);
  return () => {
    const i = hourListeners.indexOf(listener);
    if (i >= 0) hourListeners.splice(i, 1);
  };
}

/**
 * Hook a callback to fire at a specific (day, hour, minute). The callback fires
 * once when the clock reaches or passes the beat. Fires immediately if the start
 * time is already past the beat.
 */
export function onBeat(beatId: string, day: number, hour: number, minute: number, listener: BeatListener): () => void {
  const entry = { day, hour, minute, beatId, fired: false };
  scheduledBeats.push(entry);
  const beatListener: BeatListener = (bId, d, h, m) => {
    if (bId === beatId) listener(bId, d, h, m);
  };
  beatListeners.push(beatListener);
  return () => {
    const bi = scheduledBeats.indexOf(entry);
    if (bi >= 0) scheduledBeats.splice(bi, 1);
    const i = beatListeners.indexOf(beatListener);
    if (i >= 0) beatListeners.splice(i, 1);
  };
}

/** Register a story beat schedule without firing the user's listener. */
export function registerBeat(beatId: string, day: number, hour: number, minute: number) {
  scheduledBeats.push({ day, hour, minute, beatId, fired: false });
}

/** Reset beat firing state (call on new game or week reset). */
export function resetBeats() {
  for (const b of scheduledBeats) b.fired = false;
}

/**
 * Hook that drives the clock. Use exactly once inside the Canvas. Reads the current
 * time from gameStore, accumulates real time, advances the game clock, and notifies
 * hour + beat listeners.
 */
export function useTimeSystem(realSecondsPerGameMinute: number = DEFAULT_REAL_SECONDS_PER_GAME_MINUTE) {
  useFrame((_state, delta) => {
    const state = useGameStore.getState();

    // Pause when: global pause, dialogue active, phone open, not playing.
    if (state.ui.paused || state.ui.dialogueActive || state.phase !== 'playing') return;

    // Accumulate real seconds into game minutes
    const gameMinutesToAdvance = delta / realSecondsPerGameMinute;
    const prevHour = state.hour;
    const prevMinute = state.minute;
    const prevDay = state.day;

    // Advance via store action (handles hour/day rollover)
    state.advanceTime(gameMinutesToAdvance);

    const s2 = useGameStore.getState();
    const newHour = s2.hour;
    const newDay = s2.day;

    // Notify hour listeners on hour boundary
    if (newHour !== prevHour || newDay !== prevDay) {
      for (const l of hourListeners) l(newHour, newDay);
    }

    // Notify beat listeners
    for (const beat of scheduledBeats) {
      if (beat.fired) continue;
      const beatTotal = beat.day * 24 * 60 + beat.hour * 60 + beat.minute;
      const newTotal = newDay * 24 * 60 + newHour * 60 + s2.minute;
      if (newTotal >= beatTotal) {
        beat.fired = true;
        for (const l of beatListeners) l(beat.beatId, beat.day, beat.hour, beat.minute);
      }
    }
  });
}

/** Expose a non-react snapshot of the current clock. */
export function getClock() {
  const s = useGameStore.getState();
  return { day: s.day, hour: s.hour, minute: s.minute };
}
