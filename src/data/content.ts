/**
 * Content data: locations, schedules, NPCs.
 * Static data only — no runtime state here.
 */

export interface LocationDef {
  id: string;
  name: string;
  type: 'dorm' | 'athletic' | 'academic' | 'social' | 'plaza' | 'offcampus';
  building?: string;
  indoor: boolean;
  position: [number, number, number];
  size: [number, number, number]; // footprint for collision proxy
  interactionTag?: string;
  ambientAudio: string;
  hours?: [number, number]; // open range 0-24
  description: string;
}

export interface ScheduleEntry {
  location: string;
  start: number; // hour
  end: number;
  activity: string;
  role?: 'class' | 'study' | 'eat' | 'train' | 'rest' | 'social' | 'work' | 'free';
}

export interface NPCDef {
  id: string;
  name: string;
  role: 'jordan' | 'roommate' | 'coach' | 'teammate' | 'professor' | 'rival' | 'student';
  personality: string[];
  appearance: {
    skinTone: number;
    hairStyle: number;
    hairColor: number;
    build: 'slim' | 'athletic' | 'muscular' | 'stocky';
    defaultOutfit: number;
  };
  schedule: ScheduleEntry[];
  bio: string;
}

export const LOCATIONS: Record<string, LocationDef> = {
  'dorm-exterior': {
    id: 'dorm-exterior',
    name: 'Ridgeview Hall - Front',
    type: 'dorm',
    building: 'dorm-a',
    indoor: false,
    position: [-20, 0, 30],
    size: [20, 8, 16],
    interactionTag: 'dorm-a',
    ambientAudio: 'wind-campus',
    description: 'The entrance to your dorm. Students haul suitcases and say quick goodbyes to family.',
  },
  'dorm-room': {
    id: 'dorm-room',
    name: 'Your Dorm Room',
    type: 'dorm',
    building: 'dorm-a',
    indoor: true,
    position: [-20, 0, 30],
    size: [6, 3.5, 8],
    ambientAudio: 'dorm-hall',
    description: 'A small two-person room: bed, desk, closet, window overlooking the quad.',
  },
  'dorm-hall': {
    id: 'dorm-hall',
    name: 'Ridgeview Hallway',
    type: 'dorm',
    building: 'dorm-a',
    indoor: true,
    position: [-20, 0, 30],
    size: [20, 3.5, 4],
    ambientAudio: 'dorm-hall',
    description: 'Narrow cinderblock hall. Doors mostly open, music bleeding.',
  },
  'quad': {
    id: 'quad',
    name: 'Founders Quad',
    type: 'plaza',
    indoor: false,
    position: [0, 0, 10],
    size: [60, 0, 40],
    ambientAudio: 'campus-wind',
    description: 'Central lawn of North Valley State. Banner poles, benches, the monument.',
  },
  'rec-center': {
    id: 'rec-center',
    name: 'Recreation Center Plaza',
    type: 'athletic',
    building: 'rec',
    indoor: false,
    position: [10, 0, -10],
    size: [30, 12, 20],
    interactionTag: 'rec',
    ambientAudio: 'rec-exterior',
    hours: [7, 23],
    description: 'The front of the rec center. Students trail in and out with gym bags.',
  },
  'rec-gym': {
    id: 'rec-gym',
    name: 'Rec Gym',
    type: 'athletic',
    building: 'rec',
    indoor: true,
    position: [10, 0, -10],
    size: [30, 8, 40],
    interactionTag: 'gym',
    ambientAudio: 'gym-crowd',
    hours: [7, 22],
    description: 'The main court. Bleachers folded up. Hoops down. The smell of rubber.',
  },
  'basketball-gym': {
    id: 'basketball-gym',
    name: 'Ridgehawks Practice Gym',
    type: 'athletic',
    building: 'athletic-center',
    indoor: true,
    position: [30, 0, -20],
    size: [20, 10, 36],
    interactionTag: 'practice-gym',
    ambientAudio: 'gym-basketball',
    hours: [6, 21],
    description: 'The Ridgehawks practice court. Navy banners. Gold trim. Coach Riley watches.',
  },
  'athletic-offices': {
    id: 'athletic-offices',
    name: 'Athletic Offices',
    type: 'athletic',
    building: 'athletic-center',
    indoor: true,
    position: [35, 0, -18],
    size: [10, 3.5, 8],
    interactionTag: 'coach-office',
    ambientAudio: 'office-quiet',
    hours: [8, 17],
    description: 'A narrow office. Whiteboard. Game film on a monitor. Coach Riley door.',
  },
  'science-hall': {
    id: 'science-hall',
    name: 'STEM Building',
    type: 'academic',
    building: 'stem',
    indoor: true,
    position: [-10, 0, -15],
    size: [20, 12, 16],
    interactionTag: 'stem-class',
    ambientAudio: 'lecture-hall',
    hours: [7, 22],
    description: 'Stainless steel and whiteboard. Lab benches, projector, rows of seats.',
  },
  'main-classroom': {
    id: 'main-classroom',
    name: 'Lecture Hall A',
    type: 'academic',
    building: 'arts-sciences',
    indoor: true,
    position: [-25, 0, -20],
    size: [12, 5, 20],
    interactionTag: 'classroom',
    ambientAudio: 'lecture-hall',
    description: 'Tiered lecture hall. Rows curve toward a podium.',
  },
  'library': {
    id: 'library',
    name: 'Carter Library',
    type: 'academic',
    building: 'library',
    indoor: true,
    position: [-30, 0, 10],
    size: [24, 10, 20],
    interactionTag: 'library',
    ambientAudio: 'library-soft',
    hours: [7, 24],
    description: 'Three floors of books, study carrels, and the quiet hum of focus.',
  },
  'dining-hall': {
    id: 'dining-hall',
    name: 'The Commons',
    type: 'social',
    building: 'dining',
    indoor: true,
    position: [20, 0, 15],
    size: [24, 6, 20],
    interactionTag: 'dining',
    ambientAudio: 'dining-buzz',
    hours: [7, 21],
    description: 'Long tables, clattering trays, the chaos of every meal.',
  },
  'student-union': {
    id: 'student-union',
    name: 'Student Union',
    type: 'social',
    building: 'union',
    indoor: true,
    position: [5, 0, 20],
    size: [28, 6, 20],
    interactionTag: 'union',
    ambientAudio: 'union-buzz',
    description: 'Couches, a coffee counter, club tables, flyers pinned everywhere.',
  },
  'campus-store': {
    id: 'campus-store',
    name: 'Campus Store',
    type: 'social',
    building: 'union',
    indoor: true,
    position: [12, 0, 22],
    size: [8, 4, 10],
    interactionTag: 'store',
    ambientAudio: 'store-quiet',
    hours: [8, 20],
    description: 'Ridgehawks hoodies, notebooks, energy drinks. The register line.',
  },
  'off-campus-street': {
    id: 'off-campus-street',
    name: 'East Campus Avenue',
    type: 'offcampus',
    indoor: false,
    position: [-40, 0, 35],
    size: [40, 0, 8],
    ambientAudio: 'traffic-far',
    description: 'Chain coffee shops, a laundromat, a bar with neon in the window.',
  },
  'park-hidden': {
    id: 'park-hidden',
    name: 'Old Rail Park',
    type: 'plaza',
    indoor: false,
    position: [45, 0, 35],
    size: [25, 0, 18],
    ambientAudio: 'park-birds',
    description: 'A cracked field under power lines. A place people go to think.',
  },
};

export const NPCS: Record<string, NPCDef> = {
  jordan: {
    id: 'jordan',
    name: 'Jordan Hayes',
    role: 'jordan',
    personality: ['warm', 'observant', 'ambitious', 'guarded'],
    appearance: { skinTone: 4, hairStyle: 6, hairColor: 5, build: 'athletic', defaultOutfit: 8 },
    schedule: [
      { location: 'dorm-hall', start: 8, end: 9, activity: 'getting ready', role: 'free' },
      { location: 'dorm-exterior', start: 8, end: 9, activity: 'living the plaza', role: 'free' },
      { location: 'dining-hall', start: 9, end: 10, activity: 'breakfast', role: 'eat' },
      { location: 'quad', start: 10, end: 12, activity: 'pre-class walk', role: 'free' },
      { location: 'main-classroom', start: 12, end: 13, activity: 'class', role: 'class' },
      { location: 'dining-hall', start: 13, end: 14, activity: 'lunch', role: 'eat' },
      { location: 'rec-gym', start: 16, end: 18, activity: 'training', role: 'train' },
      { location: 'student-union', start: 19, end: 21, activity: 'social time', role: 'social' },
      { location: 'dorm-room', start: 22, end: 24, activity: 'rest', role: 'rest' },
    ],
    bio: 'Jordan pushed a mattress up three flights alone. Says it was fine. In a week theyve memorized the campus already. Jordan notices who sits alone.',
  },
  marcus: {
    id: 'marcus',
    name: 'Marcus Chen',
    role: 'roommate',
    personality: ['easygoing', 'funny', 'secretly driven'],
    appearance: { skinTone: 3, hairStyle: 2, hairColor: 2, build: 'slim', defaultOutfit: 4 },
    schedule: [
      { location: 'dorm-room', start: 7, end: 9, activity: 'mornings', role: 'free' },
      { location: 'dining-hall', start: 9, end: 10, activity: 'breakfast', role: 'eat' },
      { location: 'science-hall', start: 10, end: 13, activity: 'lectures', role: 'class' },
      { location: 'library', start: 14, end: 17, activity: 'study', role: 'study' },
      { location: 'quad', start: 17, end: 19, activity: 'free time', role: 'free' },
      { location: 'dining-hall', start: 19, end: 20, activity: 'dinner', role: 'eat' },
      { location: 'dorm-room', start: 21, end: 24, activity: 'wind down', role: 'rest' },
    ],
    bio: 'Marcus chose the left side without asking. Then asked if that was okay. Bio major, pre-med, terrible at pretending he is not stressed.',
  },
  coachriley: {
    id: 'coachriley',
    name: 'Coach Riley',
    role: 'coach',
    personality: ['intense', 'fair', 'private', 'demanding'],
    appearance: { skinTone: 5, hairStyle: 1, hairColor: 6, build: 'muscular', defaultOutfit: 12 },
    schedule: [
      { location: 'athletic-offices', start: 7, end: 12, activity: 'office hours / planning', role: 'work' },
      { location: 'dining-hall', start: 12, end: 13, activity: 'lunch', role: 'eat' },
      { location: 'basketball-gym', start: 14, end: 18, activity: 'practice', role: 'train' },
      { location: 'athletic-offices', start: 18, end: 20, activity: 'film review', role: 'work' },
    ],
    bio: 'Played point guard twenty years ago. Made the tournament once. Has not stopped trying to get back.',
  },
  tyrell: {
    id: 'tyrell',
    name: 'Tyrell Banks',
    role: 'rival',
    personality: ['talented', 'loud', 'insecure', 'generous when safe'],
    appearance: { skinTone: 7, hairStyle: 4, hairColor: 1, build: 'muscular', defaultOutfit: 9 },
    schedule: [
      { location: 'dorm-exterior', start: 8, end: 10, activity: 'arriving', role: 'free' },
      { location: 'basketball-gym', start: 15, end: 18, activity: 'open runs', role: 'train' },
      { location: 'quad', start: 18, end: 20, activity: 'social time', role: 'social' },
      { location: 'off-campus-street', start: 20, end: 24, activity: 'out', role: 'social' },
    ],
    bio: 'Tyrell scored nine hundred in his district last year. Everyone knows his name already. He is not sure if that is good.',
  },
  elena: {
    id: 'elena',
    name: 'Elena Reyes',
    role: 'professor',
    personality: ['sharp', 'approachable', 'no-nonsense'],
    appearance: { skinTone: 5, hairStyle: 5, hairColor: 3, build: 'slim', defaultOutfit: 11 },
    schedule: [
      { location: 'main-classroom', start: 9, end: 12, activity: 'lecture', role: 'class' },
      { location: 'main-classroom', start: 14, end: 17, activity: 'office hours', role: 'work' },
      { location: 'library', start: 17, end: 19, activity: 'research', role: 'study' },
    ],
    bio: 'Professor Reyes teaches first-year writing. She has read ten thousand essays about leaving home. She still reads every one.',
  },
};

// Quick lookup helper
export function getNPCSchedule(npcId: string, hour: number): ScheduleEntry | undefined {
  const npc = NPCS[npcId];
  if (!npc) return undefined;
  return npc.schedule.find((s) => hour >= s.start && hour < s.end);
}

export function getLocationsByType(type: LocationDef['type']): LocationDef[] {
  return Object.values(LOCATIONS).filter((l) => l.type === type);
}

export function getLocation(id: string): LocationDef | undefined {
  return LOCATIONS[id];
}
