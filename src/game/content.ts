import type { DayData, Identity, NpcDef } from './store';
import day1Json from '../../data/days/day_1.json';
import npcsJson from '../../data/dialogue/day1_npcs.json';
import identitiesJson from '../../data/characters/identities.json';

export const day1 = day1Json as DayData;
export const npcs = (npcsJson as { npcs: Record<string, NpcDef> }).npcs;
export const identities = (identitiesJson as { identities: Identity[] }).identities;
