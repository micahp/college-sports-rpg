import { create } from 'zustand';

export const STAT_KEYS = [
  'energy',
  'academics',
  'athleticism',
  'basketball_skill',
  'roommate_relationship',
  'coach_interest',
] as const;

export type StatKey = (typeof STAT_KEYS)[number];
export type Stats = Record<StatKey, number>;

export type Period = 'morning' | 'afternoon' | 'evening' | 'night';
export const PERIODS: Period[] = ['morning', 'afternoon', 'evening', 'night'];

export interface Choice {
  id: string;
  label: string;
  tags: string[];
  duration_blocks?: number;
  requirements?: { energy_min?: number };
  effects: Partial<Stats>;
  reaction: string;
}

export interface Beat {
  id: string;
  period: Period;
  title: string;
  text: string;
  choices: Choice[];
}

export interface DayData {
  day: number;
  beats: Beat[];
}

export interface NpcChoice {
  id: string;
  label: string;
  tags: string[];
  effects: Partial<Stats>;
  reaction: string;
}

export interface NpcDef {
  name: string;
  lines: string[];
  choices: NpcChoice[];
  repeat_line: string;
}

export interface Identity {
  id: string;
  name: string;
  blurb: string;
  effects: Partial<Stats>;
  tag: string;
}

const BASE_STATS: Stats = {
  energy: 70,
  academics: 50,
  athleticism: 50,
  basketball_skill: 50,
  roommate_relationship: 50,
  coach_interest: 10,
};

const clamp = (v: number) => Math.max(0, Math.min(100, Math.round(v)));

export type GamePhase =
  | 'title'
  | 'create'
  | 'play'
  | 'beat'
  | 'reaction'
  | 'tryout'
  | 'recap';

interface GameState {
  phase: GamePhase;
  day: number;
  periodIndex: number; // 0..3 index into PERIODS
  stats: Stats;
  playerName: string;
  identityId: string | null;
  traits: string[];               // accumulated choice tags
  completedBeats: string[];       // beat ids completed today
  talkedTo: string[];             // npc ids already spoken with (one-shot)
  signedUp: boolean;              // walk-on sign-up sheet
  currentBeat: Beat | null;
  pendingReaction: { text: string; effects: Partial<Stats> } | null;
  tryoutMade: number;
  tryoutAttempted: number;
  tryoutGrade: string;

  newGame: () => void;
  setIdentity: (id: string, effects: Partial<Stats>) => void;
  setPlayerName: (n: string) => void;
  startPlay: () => void;
  showBeat: (beat: Beat) => void;
  chooseBeatOption: (beat: Beat, choice: Choice) => void;
  applyNpcChoice: (npcId: string, choice: NpcChoice) => void;
  dismissReaction: () => void;
  advancePeriod: () => void;
  endDay: () => void;
  setTryoutResult: (made: number, attempted: number, grade: string) => void;
  reset: () => void;
}

export const useGame = create<GameState>((set, get) => ({
  phase: 'title',
  day: 1,
  periodIndex: 0,
  stats: { ...BASE_STATS },
  playerName: '',
  identityId: null,
  traits: [],
  completedBeats: [],
  talkedTo: [],
  signedUp: false,
  currentBeat: null,
  pendingReaction: null,
  tryoutMade: 0,
  tryoutAttempted: 0,
  tryoutGrade: '',

  newGame: () =>
    set({
      phase: 'create',
      day: 1,
      periodIndex: 0,
      stats: { ...BASE_STATS },
      playerName: '',
      identityId: null,
      traits: [],
      completedBeats: [],
      talkedTo: [],
      signedUp: false,
      currentBeat: null,
      pendingReaction: null,
      tryoutMade: 0,
      tryoutAttempted: 0,
      tryoutGrade: '',
    }),

  setIdentity: (id, effects) =>
    set((s) => ({
      identityId: id,
      stats: applyEffects(s.stats, effects),
    })),

  setPlayerName: (n) => set({ playerName: n }),

  startPlay: () => set({ phase: 'play' }),

  showBeat: (beat) => set({ phase: 'beat', currentBeat: beat }),

  chooseBeatOption: (beat, choice) =>
    set((s) => ({
      stats: applyEffects(s.stats, choice.effects),
      traits: [...s.traits, ...choice.tags],
      completedBeats: [...s.completedBeats, beat.id],
      signedUp: s.signedUp || beat.id === 'evening_coach',
      phase: 'reaction',
      pendingReaction: { text: choice.reaction, effects: choice.effects },
      currentBeat: null,
    })),

  applyNpcChoice: (npcId, choice) =>
    set((s) => ({
      stats: applyEffects(s.stats, choice.effects),
      traits: [...s.traits, ...choice.tags],
      talkedTo: s.talkedTo.includes(npcId) ? s.talkedTo : [...s.talkedTo, npcId],
      signedUp: s.signedUp || npcId === 'coach',
      phase: 'reaction',
      pendingReaction: { text: choice.reaction, effects: choice.effects },
    })),

  dismissReaction: () => {
    const s = get();
    autosave();
    const beatCount = s.completedBeats.length;
    const nextPeriod = Math.min(beatCount, PERIODS.length - 1);
    if (beatCount >= PERIODS.length) {
      set({ phase: 'tryout', pendingReaction: null });
    } else {
      set({ phase: 'play', pendingReaction: null, periodIndex: nextPeriod });
    }
  },

  advancePeriod: () =>
    set((s) => ({ periodIndex: Math.min(s.periodIndex + 1, PERIODS.length - 1) })),

  endDay: () => set({ phase: 'recap' }),

  setTryoutResult: (made, attempted, grade) =>
    set({ tryoutMade: made, tryoutAttempted: attempted, tryoutGrade: grade, phase: 'recap' }),

  reset: () => {
    localStorage.removeItem('the-u-save');
    set({
      phase: 'title',
      day: 1,
      periodIndex: 0,
      stats: { ...BASE_STATS },
      playerName: '',
      identityId: null,
      traits: [],
      completedBeats: [],
      talkedTo: [],
      signedUp: false,
      currentBeat: null,
      pendingReaction: null,
    });
  },

}));

export function applyEffects(stats: Stats, effects: Partial<Stats>): Stats {
  const next = { ...stats };
  for (const k of STAT_KEYS) {
    const d = effects[k];
    if (typeof d === 'number') next[k] = clamp(next[k] + d);
  }
  return next;
}

export function primaryTrait(traits: string[]): string {
  const counts: Record<string, number> = {};
  for (const t of traits) counts[t] = (counts[t] ?? 0) + 1;
  let best = 'social';
  let bestN = -1;
  for (const [t, n] of Object.entries(counts)) {
    if (n > bestN) {
      best = t;
      bestN = n;
    }
  }
  return best;
}

// ---------- Save / Load ----------
const SAVE_KEY = 'the-u-save';

interface SaveData {
  day: number;
  periodIndex: number;
  stats: Stats;
  playerName: string;
  identityId: string | null;
  traits: string[];
  completedBeats: string[];
  talkedTo: string[];
  signedUp: boolean;
}

export function saveGame(): boolean {
  try {
    const s = useGame.getState();
    const data: SaveData = {
      day: s.day,
      periodIndex: s.periodIndex,
      stats: { ...s.stats },
      playerName: s.playerName,
      identityId: s.identityId,
      traits: [...s.traits],
      completedBeats: [...s.completedBeats],
      talkedTo: [...s.talkedTo],
      signedUp: s.signedUp,
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(data));
    return true;
  } catch {
    return false;
  }
}

export function loadGame(): SaveData | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as SaveData;
  } catch {
    return null;
  }
}

export function hasSave(): boolean {
  return localStorage.getItem(SAVE_KEY) !== null;
}

export function restoreGame(): boolean {
  const data = loadGame();
  if (!data) return false;
  useGame.setState({
    phase: 'play',
    day: data.day,
    periodIndex: data.periodIndex,
    stats: data.stats,
    playerName: data.playerName,
    identityId: data.identityId,
    traits: data.traits,
    completedBeats: data.completedBeats,
    talkedTo: data.talkedTo,
    signedUp: data.signedUp,
    currentBeat: null,
    pendingReaction: null,
  });
  return true;
}

// Autosave after every beat/choice.
export function autosave() {
  saveGame();
}
