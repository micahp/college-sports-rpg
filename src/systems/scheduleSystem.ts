/**
 * scheduleSystem — NPC planner.
 *
 * Given the current day + hour, compute where each NPC should be and what they're doing
 * using the static schedules in content.ts (via getNPCSchedule). NPCs between scheduled
 * slots are treated as "in transit" — scheduleSystem returns their previous + next
 * locations so NpcManager can animate a walk instead of snapping.
 *
 * Day-of-week awareness: the schedule is keyed on hour, and day mod 7 distinguishes
 * weekday (0-4) vs weekend (5-6).
 */
import { NPCS, getNPCSchedule, LOCATIONS } from '../data/content';
import type { ScheduleEntry } from '../data/content';
import { useGameStore } from '../store/gameStore';

// ---------------------------------------------------------------------------
// Tuning
// ---------------------------------------------------------------------------
/** Minutes before a schedule entry transition that an NPC begins walking to the next spot. */
const TRANSITION_LOOKAHEAD_MIN = 15;

export interface NpcPosition {
  npcId: string;
  locationId: string;
  position: [number, number, number];
  activity: string;
  /** True if the NPC is mid-transit between locations. */
  inTransit: transitInfo | null;
}

export interface transitInfo {
  fromLocationId: string;
  toLocationId: string;
  progress: number; // 0..1 — 0 = left previous spot, 1 = arrived next
  fromPos: [number, number, number];
  toPos: [number, number, number];
}

/** Compute a world position for a location id, adding a small per-NPC offset. */
function locationPosition(locationId: string, npcId: string): [number, number, number] {
  const loc = LOCATIONS[locationId];
  if (!loc) return [0, 0, 0];
  // Pseudo-random but stable offset so NPCs in the same room don't stack.
  const hash = hash2(npcId, locationId);
  const ox = (hash % 7) * 0.6 - 1.8;
  const oz = ((hash >> 3) % 7) * 0.6 - 1.8;
  return [loc.position[0] + ox, loc.position[1], loc.position[2] + oz];
}

function hash2(a: string, b: string): number {
  let h = 0;
  const s = a + '|' + b;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h);
}

/**
 * Primary export: compute every NPC's intended location + position at (day, hour).
 *
 * Walk/teleport logic:
 *  - If an NPC has a schedule entry that covers this hour, they are AT that location.
 *  - If they are within TRANSITION_LOOKAHEAD_MIN of the next slot's start, they are
 *    in transit between the previous location and the next location.
 *  - If the hour falls in a gap between schedule entries (e.g. the NPC has a slot
 *    ending at 12 and next starting at 14), they are "free" — they stay at the previous
 *    location with a 'free' activity so NpcManager doesn't teleport them.
 */
export function getNpcPositions(day: number, hour: number): Record<string, NpcPosition> {
  const result: Record<string, NpcPosition> = {};
  const minute = 0; // coarse per-hour grid; engines that need sub-hour use getNpcPositionsAtMinute

  for (const npcId of Object.keys(NPCS)) {
    const npc = NPCS[npcId];
    const pos = computeNpcPosition(npc, day, hour, minute);
    result[npcId] = { npcId, ...pos };
  }
  return result;
}

/**
 * Sub-hour variant: pass a continuous minute-of-day so transitions can animate smoothly.
 */
export function getNpcPositionsAtMinute(day: number, minuteOfDay: number): Record<string, NpcPosition> {
  const hour = Math.floor(minuteOfDay / 60) % 24;
  const minute = minuteOfDay % 60;
  const result: Record<string, NpcPosition> = {};
  for (const npcId of Object.keys(NPCS)) {
    const npc = NPCS[npcId];
    const pos = computeNpcPosition(npc, day, hour, minute);
    result[npcId] = { npcId, ...pos };
  }
  return result;
}

function computeNpcPosition(
  npc: { id: string; schedule: ScheduleEntry[] },
  day: number,
  hour: number,
  minute: number
): Omit<NpcPosition, 'npcId'> {
  const schedule = npc.schedule;
  if (!schedule || schedule.length === 0) {
    // No schedule = stay at dorm exterior.
    return {
      locationId: 'dorm-exterior',
      position: locationPosition('dorm-exterior', npc.id),
      activity: 'idle',
      inTransit: null,
    };
  }

  // Sort by start time just in case content order isn't guaranteed.
  const sorted = [...schedule].sort((a, b) => a.start - b.end);

  // Find the currently-active entry.
  const active = sorted.find((s) => hour >= s.start && hour < s.end);

  if (active) {
    // Check if we're close to the end — if so, set up a transit to the next entry.
    const endMinute = active.end * 60;
    const nowMinute = hour * 60 + minute;
    const minutesUntilEnd = endMinute - nowMinute;

    // Look up what comes after this entry.
    const idx = sorted.indexOf(active);
    const nextEntry = idx < sorted.length - 1 ? sorted[idx + 1] : null;

    if (nextEntry && minutesUntilEnd <= TRANSITION_LOOKAHEAD_MIN && minutesUntilEnd >= 0) {
      const progress = 1 - minutesUntilEnd / TRANSITION_LOOKAHEAD_MIN;
      return {
        locationId: active.location,
        position: lerpPosition(
          locationPosition(active.location, npc.id),
          locationPosition(nextEntry.location, npc.id),
          progress
        ),
        activity: active.activity,
        inTransit: {
          fromLocationId: active.location,
          toLocationId: nextEntry.location,
          progress,
          fromPos: locationPosition(active.location, npc.id),
          toPos: locationPosition(nextEntry.location, npc.id),
        },
      };
    }

    return {
      locationId: active.location,
      position: locationPosition(active.location, npc.id),
      activity: active.activity,
      inTransit: null,
    };
  }

  // No entry covers this hour. Find the previous and next to handle gaps.
  let prev: ScheduleEntry | null = null;
  let next: ScheduleEntry | null = null;
  for (const s of sorted) {
    if (s.end <= hour) prev = s;
    if (s.start > hour && !next) next = s;
  }

  // Weekend override: weekday-only schedules get "free time" on weekends.
  const isWeekend = day % 7 >= 5;
  if (isWeekend && !active) {
    // Treat as free at the last known location.
    const stayLoc = prev ? prev.location : 'quad';
    return {
      locationId: stayLoc,
      position: locationPosition(stayLoc, npc.id),
      activity: 'free time',
      inTransit: null,
    };
  }

  // Gap handling: stay at previous location with 'free' activity (no teleport).
  if (prev) {
    return {
      locationId: prev.location,
      position: locationPosition(prev.location, npc.id),
      activity: 'free',
      inTransit: null,
    };
  }

  // Before first slot: stay at dorm-exterior.
  if (next) {
    return {
      locationId: 'dorm-exterior',
      position: locationPosition('dorm-exterior', npc.id),
      activity: 'getting ready',
      inTransit: null,
    };
  }

  return {
    locationId: 'quad',
    position: locationPosition('quad', npc.id),
    activity: 'free',
    inTransit: null,
  };
}

function lerpPosition(
  a: [number, number, number],
  b: [number, number, number],
  t: number
): [number, number, number] {
  const ct = Math.max(0, Math.min(1, t));
  return [a[0] + (b[0] - a[0]) * ct, a[1] + (b[1] - a[1]) * ct, a[2] + (b[2] - a[2]) * ct];
}

/** Convenience: current NPC positions using the live gameStore clock. */
export function getNpcPositionsNow(): Record<string, NpcPosition> {
  const s = useGameStore.getState();
  return getNpcPositionsAtMinute(s.day, s.hour * 60 + s.minute);
}
